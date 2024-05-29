
(* Imperative infinite streams *)

signature STREAM = sig
  type 'a stream
  val new  : (unit -> 'a) -> 'a stream
  val put  : 'a * 'a stream -> 'a stream
  val get  : 'a stream -> 'a * 'a stream
  val iota : unit -> int stream
  val map  : ('a -> 'b) -> 'a stream -> 'b stream
  val take : 'a stream -> int -> 'a list * 'a stream
end

structure Stream :> STREAM = struct

datatype 'a str = VAL of 'a * 'a stream | FN of unit -> 'a
withtype 'a stream = 'a str ref

fun new f = ref(FN f)

fun put (v:'a, s:'a stream) : 'a stream =
    ref(VAL(v,s))

fun get (s:'a stream) : 'a * 'a stream =
    case !s of
        VAL p => p
      | FN f => let val t = (f(),ref(FN f))
                in s := VAL t ; t
                end

fun iota () : int stream =
    let val r = ref 0
        fun next () = !r before r := !r + 1
    in new next
    end

fun map (f: 'a -> 'b) (s:'a stream) : 'b stream =
    case !s of
        VAL (v,s) => ref(VAL(f v,map f s))
      | FN g => ref(FN(f o g))

fun take (s: 'a stream) (n:int) : 'a list * 'a stream =
    let fun loop s n acc = if n <= 0 then (rev acc,s)
                           else let val (v,s) = get s
                                in loop s (n-1) (v :: acc)
                                end
    in loop s n nil
    end

end
