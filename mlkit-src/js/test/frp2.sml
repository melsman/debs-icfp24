(* Reactive Web Programming *)

signature ARROW0 = sig
  type ('b,'c,'k) arr
  val arr : (''b -> ''c) -> (''b,''c,'k) arr
  val >>> : (''b,''c,'k)arr * (''c,''d,'k)arr -> (''b,''d,'k)arr                                       
  val fst : (''b,''c,'k)arr -> (''b*''d,''c*''d,'k)arr
end

signature ARROW = sig
  include ARROW0
  val snd : (''b,''c,'k)arr -> (''d*''b,''d*''c,'k)arr
  val *** : (''b,''c,'k)arr * (''d,''e,'k)arr -> (''b*''d,''c*''e,'k)arr
  val &&& : (''b,''c,'k)arr * (''b,''d,'k)arr -> (''b,''c*''d,'k)arr
end

signature TIME_VAL =
sig
  type B type E (* kinds: Behaviors (B) and Events (E) *)
  type ('a,'k)t
  type 'a b = ('a,B)t
  type 'a e = ('a,E)t

  include ARROW 
  where type ('a,'b,'k)arr = ('a,'k)t -> ('b,'k)t

  val insertDOM : string b * string -> unit
  val timer     : int -> Time.time b
  val textField : string -> string b
  val mouseOver : string -> bool b
  val mouse     : unit -> (int*int) b
  val pair      : ''a b * ''b b -> (''a * ''b) b
  val merge     : ''a e * ''a e -> ''a e
  val delay     : int -> (''a,''a,B)arr
  val calm      : int -> (''a,''a,B)arr
  val fold      : (''a * ''b -> ''b) -> ''b -> ''a e -> ''b e
  val click     : string -> ''a -> ''a e
  val changes   : ''a b -> ''a e
  val hold      : ''a -> ''a e -> ''a b
  val const     : ''a -> ''a b
  val empty     : unit -> ''a e
  val current   : ''a b -> ''a
  val poll      : (unit -> ''a) -> int -> ''a b

  val addListener : (''a,'k)t -> (''a -> unit) -> unit 
end

structure TimeVal :> TIME_VAL =
struct

fun idError s id = 
    raise Fail (s ^ ": element with id=" ^ id ^ " not in dom")

datatype kind = Behavior | Event
type B = kind
type E = kind
type ('a,'k) t = 
     {listeners: ('a -> unit) list ref,
      newValue : 'a -> unit,
      current: 'a ref option}

type 'a b = ('a,B)t
type 'a e = ('a,E)t

fun new (init:''a option) : (''a,'k) t =
    let val listeners = ref nil
    in case init of
         SOME a =>
         let val current = ref a
         in {listeners=listeners,
             current=SOME current,
             newValue=fn v => if v = !current then ()
                              else (current := v; 
                                    app (fn f => f v) (rev(!listeners)))}
         end
       | NONE =>
         {listeners=listeners,
          current=NONE,
          newValue=fn v => app (fn f => f v) (rev(!listeners))}
    end

fun current ({current,...}:(''a,B)t) : ''a =
    case current of
      SOME(ref v) => v
    | NONE => raise Fail "current.impossible"

fun addListener ({listeners,...}: ('a,'k)t) f =
    listeners := (f :: (!listeners))

fun fstT (eP : (''a*''b,'k)t) : (''a,'k)t =
    let val v1opt = case #current eP of
                      SOME(ref(v1,_)) => SOME v1
                    | NONE => NONE
        val e : (''a,'k)t = new v1opt
        val _ = addListener eP (#newValue e o #1)
    in e
    end

fun sndT (eP : (''a*''b,'k)t) : (''b,'k)t =
    let val v2opt = case #current eP of
                      SOME(ref(_,v2)) => SOME v2
                    | NONE => NONE
        val e : (''b,'k)t = new v2opt
        val _ = addListener eP (#newValue e o #2)
    in e
    end

local 
  fun get(r as ref(x::xs)) = SOME x before r:=xs
    | get(ref nil) = NONE
  fun add(r) x = r := rev(x::(rev(!r)))
in
fun pairT (e1: (''a,'k)t, e2: (''b,'k)t) : (''a*''b,'k)t =
    case (#current e1, #current e2) of
      (SOME v1r, SOME v2r) => (* behaviors *)
      let val e : (''a*''b,'k) t = new (SOME(!v1r,!v2r))
          val _ = addListener e1 (fn v1: ''a => #newValue e (v1,!v2r))
          val _ = addListener e2 (fn v2: ''b => #newValue e (!v1r,v2))
      in e
      end      
    | (NONE,NONE) => (* event streams *)
      let val e1s = ref (nil : ''a list)
          val e2s = ref (nil : ''b list)
          val e : (''a*''b,'k)t = new NONE
          val _ = addListener e1 (fn v1: ''a => case get e2s of 
                                                  NONE => add e1s v1
                                                | SOME v2 => #newValue e (v1,v2))
          val _ = addListener e2 (fn v2: ''b => case get e1s of
                                                  NONE => add e2s v2
                                                | SOME v1 => #newValue e (v1,v2))
      in e
      end
    | _ => raise Fail "pairT.impossible"
end

val pair = pairT

fun merge (e1: (''a,E)t, e2: (''a,E)t) : (''a,E)t =
    let val e = new NONE
        val _ = addListener e1 (#newValue e)
        val _ = addListener e2 (#newValue e)
    in e
    end

fun insertDOM (b : (string,B)t, id : string) =
    case Js.getElementById Js.document id of
      SOME e => 
      (case #current b of
         SOME(ref v) => (Js.innerHTML e v;
                         addListener b (Js.innerHTML e))
       | NONE => raise Fail "insertDOM impossible")
    | NONE => idError "insertDOM" id

fun delay (ms:int) (b : (''a,B)t) : (''a,B)t =
    let val b' = new(case #current b of 
                       SOME(ref v) => SOME v 
                     | NONE => raise Fail "delay.impossible")
        val _ = addListener b (fn v =>
                                  (Js.setTimeout ms (fn () => #newValue b' v); ()))
    in b'
    end

fun calm (ms:int) (b : (''a,B)t) : (''a,B)t =
    let val b' = new(case #current b of
                       SOME(ref v) => SOME v 
                     | NONE => raise Fail "calm.impossible")
        val c = ref 0
        fun incr c = c := !c + 1
        fun decr c = (c := !c - 1; !c = 0) 
        val _ = addListener b (fn v => 
                                  (incr c;
                                  (Js.setTimeout ms (fn () => 
                                                        if decr c then #newValue b' v
                                                        else ())); ()))
    in b'
    end

fun textField (id:string) : (string,B) t =
    case Js.getElementById Js.document id of
      SOME e => let
                  val b = new (SOME(Js.value e))
                  fun f () = (#newValue b (Js.value e); true)
                  val () = Js.installEventHandler e Js.onkeyup f                                                   
                in b
                end 
    | NONE => idError "textField" id

fun mouseOver (id:string) : (bool,B)t =
    case Js.getElementById Js.document id of
      SOME e => let
                  val b = new(SOME false)
                  fun f over () = (#newValue b over; true)
                  val () = Js.installEventHandler e Js.onmouseover (f true)
                  val () = Js.installEventHandler e Js.onmouseout (f false)
                in b
                end 
    | NONE => idError "mouseOver" id

fun mouse() : (int*int,B)t =
    let val b = new(SOME(0,0))
        val () = Js.onMouseMove Js.document (#newValue b)
    in b
    end

fun click (id:string) (a:''a) : (''a,E)t =
    case Js.getElementById Js.document id of
      SOME e => let val t = new NONE
                    val () = Js.installEventHandler e Js.onclick (fn() => (#newValue t a; true))
                in t
                end
    | NONE => idError "click" id

fun changes (b: (''a,B)t) : (''a,E)t =
    let val t = new NONE
        val _ = addListener b (#newValue t)
    in t
    end

fun hold (a : ''a) (e: (''a,E)t) : (''a,B)t =
    let val b = new(SOME a)
        val _ = addListener e (#newValue b)
    in b
    end

(*
fun fold (f:''a*''b -> ''b) (x:''b) (a:(''a,'k)t) : (''b,B)t =
    let val b : (''b,B)t = new(SOME x)
        val _ = addListener a (fn v => 
                                  case #current b of
                                    SOME (ref c) => #newValue b (f(v,c))
                                  | NONE => raise Fail "fold.impossible")
    in b
    end
*)

fun fold (f:''a*''b -> ''b) (x:''b) (a:(''a,E)t) : (''b,E)t =
    let val t = ref x
        val es : (''b,E)t = new(NONE)
        val _ = addListener a (fn v => let val r = f(v,!t)
                                       in t := r; #newValue es r
                                       end)
    in es
    end

fun empty() : (''a,E)t = new NONE

fun const (a:''a) : (''a,B)t = new (SOME a)

fun poll (f: unit -> ''a) (ms:int) : (''a,B)t = 
    let val b = new (SOME (f()))
        (* This could  be optimized so that we don't do unnecessary 
         * f-work when there is no listeners... *)
        val _ = Js.setInterval ms (#newValue b o f)
    in b
    end

fun timer m = poll Time.now m

type ('a,'b,'k) arr = ('a,'k)t -> ('b,'k)t

fun arr (f: ''a -> ''b) (b0:(''a,'k)t) =
    let val b = new(case #current b0 of
                      SOME(ref v) => SOME (f v)
                    | NONE => NONE)
      val _ = addListener b0 (fn v => #newValue b (f v))
    in b
    end

fun fst f = fn p => pairT(f(fstT p),sndT p)

infix >>> *** &&&

fun a1 >>> a2 = a2 o a1

fun snd f = 
    let fun swap (a,b) = (b,a)
    in arr swap >>> fst f >>> arr swap
    end

fun f *** g = fst f >>> snd g

fun f &&& g = arr (fn b => (b,b)) >>> (f *** g) 

end
