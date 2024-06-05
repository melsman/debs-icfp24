infix  7  * / div mod
infix  6  + - ^
infixr 5  :: @
infix  4  = <> > >= < <=
infix  3  := o
infix  0  before

signature THREAD = sig
  type 'a t
  val spawn : (unit->'a) -> ('a t->'b) -> 'b
  val get   : 'a t -> 'a
end

fun print (s:string) : unit = prim("printStringML", s)
fun printNum (i:int) : unit = prim("printNum", i)


structure T :> THREAD = struct
  type 'a t = 'a
  fun spawn f k = k(f())
  fun get x = x
end

(*
structure T :> THREAD = struct
  datatype 'a t = V of unit -> 'a
  fun spawn f k = k(V f)
  fun get (V f) = f()
end
*)

structure T2 :> THREAD = struct

  (* Note: By representing a thread by a pair of the thread function
     and the pointer to the C-managed data structure for the thread, we
     can make sure that all non-local regions accessed in the thread
     body are live until the thread terminates (the effect in the
     thread function type will mention all such referenced regions.)

     We'll convert the function closure value to a foreignptr (called
     'cp'), which we can pass to the C 'spawnone' function, which is
     really an MLKit primitive. The 'spawnone' function will spawn a
     thread and return a handle to the C-managed data structure.

     To spawn a tread, the MLKit compiler will generate the following
     x64 assembler code for the 'spawnone' primitive:

          Generated pseudo code:   ; assume argument closure pointer is in cp
            ...
            mov call_closure, %eax
            mov cp, %ebx
            push ret_thread_create
            jmp thread_create
          lab call_closure:
            mov %eax, tmp
            load tmp(0), cfp
            load tmp(1), ep
            mov ep %eax
            push ret_call_closure
            jmp cfp                ; maybe adjust %esp
          lab ret_call_closure:
            mov %erx, %eax         ; mv ML ret value into c argument
            call thread_exit       ; call c function thread_exit
            mov 0, %esp
            ret
          lab ret_thread_create:
            mov %erx, %eax         ; leave result in %eax
            ...

     Parts of the generated code is a C function stub 'call_closure',
     which takes the closure pointer 'cp' as argument and returns 0;
     the pointer to this function is passed to the 'thread_create'
     function (defined in Spawn.c) together with the closure pointer
     'cp'. The function 'call_closure' extracts the environment
     pointer 'ep' and the closure function pointer 'cfp' from 'cp'. It
     then calls 'cfp' using the MLKit calling conventions; it passes
     'ce' as an argument and pushes the return address on the
     stack. Upon return from the ML function, 'call_closure' will call
     the 'thread_exit' function with the return value as argument.

     The get function will block on the thread and return the value
     produced by the thread. In case an exception is raised by the
     thread, the get function will raise this exception (whenever the
     get function is called.)

     It is important that the functions spawn and get are not inlined
     (and then specialized) by the optimiser, as that would destroy
     the property of the functions getting polymorphic types. For
     instance, if specialised, the function get may get the type "int
     list t -> int list", which would allow region inference to assign
     different regions to the argument and the result. The same goes
     for the spawn-function.
   *)

  fun !(x: 'a ref): 'a = prim ("!", x)

  type thread = foreignptr
  datatype 'a res = Ok of 'a | Exn of exn
  type 'a t0 = ((unit->'a) * thread) ref
  fun get__noinline ((ref (f,t0)): 'a t0) : 'a = prim("thread_get", t0)
  fun spawn__noinline (f: unit->'a) (k: 'a t0 -> 'b) : 'b =
      let val rf : (unit -> 'a) ref = ref f
          val fp_f : foreignptr = prim("pointer", !rf)

          (* From a region inference perspective, coercing the type of
           * a function to a pointer type is very unsafe, as the
           * pointer type contains no information about which regions
           * need to be kept alive for the pointer value to be
           * valid. By including the type of the function in the type
           * of the thread value, however, we keep all necessary
           * regions alive.
           *
           * Moreover, we encapsulate the function in a ref to avoid
           * that the closure is inlined into the "pointer" prim
           * argument. If it is inlined, the closure will be allocated
           * in a local stack-allocated region inside the "pointer"
           * prim value, which cause the program to segfault.. *)

          (* val () = prim("function_test", fp_f) *)
          val t0 : thread = prim("spawnone", fp_f)
          val t: 'a t0 = ref (f,t0)

          fun force () =
              if !(ref true)          (* make sure the thread has terminated before returning *)
              then get__noinline t    (* and mimic that, from a type perspective, spawn has *)
              else !rf()              (* the effect of calling f *)

          val res = k t handle e => (force() ; raise e)
          val _ = force ()

          (* Notice that it is not safe to call `thread_free t0` here
           * as t0 may be live through later calls to `get t`.
           *
           * What is needed is for the ThreadInfo structs to be region allocated and to
           * add finalisers (thread_free) to objects in these regions. I wonder whether
           * we can detach the thread already in the thread_get function (the mutex and
           * the ThreadInfo struct must be kept live of course.
           *)

          (* val () = prim("thread_free", t0) *)
      in res
      end

  (* Now, make it work when a thread raises an exception *)
  datatype 'a res = Ok of 'a | Exn of exn
  type 'a t = 'a res t0
  fun spawn (f: unit->'a) (k: 'a t -> 'b) : 'b =
      let fun f' () = Ok (f ()) handle e => Exn e
      in spawn__noinline f' k
      end
  fun get (x:'a t) : 'a =
      case get__noinline x of
          Ok v => v
        | Exn e => raise e
end

structure T = T2

fun fib n = if n < 2 then 1 else fib (n-1) + fib (n-2)

fun run1 () =
    T.spawn (fn () =>
                let val x = fib 2
                in raise Div
                end) (fn t => raise Match)
    handle Match => printNum 1
         | Div => printNum 0

fun run2 () =
    printNum
        (T.spawn (fn () => fib 20) (fn t => raise Match)
         handle Match => 1
              | Div => 0)

fun run3 () =
    printNum
        (T.spawn (fn () => raise Match) (fn t => 1)
         handle Match => 8
              | Div => 0)

val () = run1()

val () = run2()

val () = run3()
