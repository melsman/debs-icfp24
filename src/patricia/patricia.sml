(* Finite maps based on Patricia Trees. Source code adapted from
 * Okasaki & Gill, "Fast Mergeable Integer Maps", ML Workshop '98.
 * ME 1998-10-21.
 *)

signature MONO_MAP = sig
  type dom
  type 'b map

  val empty      : 'a map
  val singleton  : dom * 'a -> 'a map
  val isEmpty    : 'a map -> bool
  val lookup     : 'a map -> dom -> 'a option
  val add        : dom * 'a * 'a map -> 'a map
  val plus       : 'a map * 'a map -> 'a map
  val remove     : dom * 'a map -> 'a map option
  val dom        : 'a map -> dom list
  val range      : 'a map -> 'a list
  val list       : 'a map -> (dom * 'a) list
  val fromList   : (dom * 'a) list -> 'a map
  val map        : ('a -> 'b) -> 'a map -> 'b map
  val Map        : (dom * 'a -> 'b) -> 'a map -> 'b map
  val fold       : ('a * 'b -> 'b) -> 'b -> 'a map -> 'b
  val Fold       : ((dom * 'a) * 'b -> 'b) -> 'b -> 'a map -> 'b
  val filter     : (dom * 'b -> bool) -> 'b map -> 'b map
  val addList    : (dom * 'b) list -> 'b map -> 'b map
  val merge      : ('a * 'a -> 'a) -> 'a map -> 'a map -> 'a map
end

structure IntFinMap :> MONO_MAP where type dom = int =
struct
  type dom = int

  (* helper functions *)
  open Word
  fun lowestBit x = andb (x,0w0 - x)
  fun max (x,y) = if x>y then x else y
  fun highestBit (x,m) =
    let val x' = andb (x,notb (m-0w1))
        fun highb (x,m) =
          if x=m then m else highb (andb (x,notb m),m+m)
    in highb (x',m) end
  fun branchingBit (m,p0,p1) = highestBit (xorb (p0,p1), m)
  fun mask (k,m) = orb (k,m-0w1+m) - m
  fun zeroBit (k,m) = (andb (k,m) = 0w0)
  fun matchPrefix (k,p,m) = (mask (k,m) = p)
  fun swap (x,y) = (y,x)

  datatype 'a map = Empty
	          | Lf of word * 'a
	          | Br of word * word * 'a map * 'a map
  (*
   * Lf (k,x):
   *   k is the key
   * Br (p,m,t0,t1):
   *   p is the largest common prefix for all the keys in this tree
   *   m is the branching bit
   *     (m is a power of 2, only the bits above m are valid in p)
   *   t0 contains all the keys with a 0 in the branching bit
   *   t1 contains all the keys with a 1 in the branching bit
   *)

  val empty = Empty

  fun check s d = if Int.<(d, 0) then print ("IntMap." ^ s ^ " error\n")
		  else ()

  fun singleton (d,r) =
    ((* check "singleton" d; *)
     Lf (fromInt d, r))

  fun isEmpty Empty = true
    | isEmpty _ = false

  fun lookup t k =
    let val w = fromInt k
        fun look Empty = NONE
          | look (Lf (j,x)) = if j=w then SOME x else NONE
          | look (Br (p,m,t0,t1)) =
              if w <= p then look t0
                        else look t1
    in (*check "lookup" k;*) look t end

  fun join (m,p0,t0,p1,t1) =
    (* combine two trees with prefixes p0 and p1,
     * where p0 and p1 are known to disagree
     *)
    let val m = branchingBit (m,p0,p1)
    in if p0 < p1 then Br (mask (p0,m), m, t0, t1)
                  else Br (mask (p0,m), m, t1, t0)
    end

  fun insertw c (w,x,t) =
    let fun ins Empty = Lf (w,x)
          | ins (t as Lf (j,y)) =
              if j=w then Lf (w,c (x,y))
              else join (0w1,w,Lf (w,x),j,t)
          | ins (t as Br (p,m,t0,t1)) =
              if matchPrefix (w,p,m) then
                if w <= p then Br (p,m,ins t0,t1)
                          else Br (p,m,t0,ins t1)
              else join (m+m,w,Lf (w,x),p,t)
    in ins t end

  fun add (k,x,t) = ((*check "add" k;*) insertw #1 (fromInt k,x,t))   (* was #2 *)

  fun merge c (s,t) =
    let fun mrg (s as Br (p,m,s0,s1), t as Br (q,n,t0,t1)) =
              if m<n then
                if matchPrefix (p,q,n) then
                  if p <= q then Br (q,n,mrg (s,t0),t1)
                           else Br (q,n,t0,mrg (s,t1))
                else join (n+n,p,s,q,t)
              else if m>n then
                if matchPrefix (q,p,m) then
                  if q <= p then Br (p,m,mrg (s0,t),s1)
                           else Br (p,m,s0,mrg (s1,t))
                else join (m+m,p,s,q,t)
              else (* if m=n then *)
                if p=q then Br (p,m,mrg (s0,t0),mrg (s1,t1))
                else join (m+m,p,s,q,t)
          | mrg (t as Br _, Lf (w,x)) = insertw (c o swap) (w,x,t)
          | mrg (t as Br _, Empty) = t
          | mrg (Lf (w,x), t) = insertw c (w,x,t)
          | mrg (Empty, t) = t
    in mrg (s,t)
    end

  fun plus (s,t) = merge #2 (s,t)

  fun mergeMap c s t = merge c (s,t)
  val merge = mergeMap

  fun fold f b Empty = b
    | fold f b (Lf(w,e)) = f(e,b)
    | fold f b (Br(_,_,t1,t2)) = fold f (fold f b t1) t2

  fun Fold f b Empty = b
    | Fold f b (Lf(w,e)) = f((toInt w,e),b)
    | Fold f b (Br(_,_,t1,t2)) = Fold f (Fold f b t1) t2

  fun remove (d,t) =  (* not terribly efficient! *)
    case ((* check "remove" d;*) lookup t d)
      of SOME _ => SOME(Fold (fn ((d',e),a) => if d=d' then a
					       else add(d',e,a)) Empty t)
       | NONE => NONE

  fun composemap f Empty = Empty
    | composemap f (Lf(w,e)) = Lf(w,f e)
    | composemap f (Br(q1,q2,t1,t2)) = Br(q1,q2,composemap f t1, composemap f t2)

  fun ComposeMap f Empty = Empty
    | ComposeMap f (Lf(w,e)) = Lf(w,f(toInt w,e))
    | ComposeMap f (Br(q1,q2,t1,t2)) = Br(q1,q2,ComposeMap f t1, ComposeMap f t2)

  fun app f Empty = ()
    | app f (Lf(w,e)) = f e
    | app f (Br(_,_,t1,t2)) = (app f t1; app f t2)

  fun dom t =
    let fun d (Empty, a) = a
	  | d (Lf(w,e), a) = toInt w :: a
	  | d (Br(_,_,t1,t2), a) = d(t2,d(t1,a))
    in d(t,[])
    end

  fun range m = fold (op ::) nil m
  fun list m = Fold (op ::) nil m
  fun filter f m = Fold (fn (e as (d,r),a) => if f e then add(d,r,a)
					      else a) Empty m

  fun addList [] m = m
    | addList ((d,r)::rest) m = addList rest (add(d,r,m))

  fun fromList l = addList l Empty

  val map = composemap
  val Map = ComposeMap
end


(* Tests *)

functor Test () : sig end =
  struct
    structure IFM = IntFinMap
    fun member [] e = false
      | member (x::xs) e = x=e orelse member xs e

    infix ===
    fun l1 === l2 =
      foldl (fn (x,b) => b andalso member l2 x) (length l1 = length l2) l1

    fun mk [] = []
      | mk (x::xs) = (x,Int.toString x)::mk xs

    fun mk' [] = []
      | mk' (x::xs) = (x,Int.toString x ^ "'")::mk' xs

    val l1 = mk [12,234,345,23,234,6,456,78,345,23,78,79,657,345,234,456,78,0,7,45,3,56,578,7,567,345,35,2,456,57,8,5]
    val l2 = mk' [23,43,4,456,456,23,4523,4,47,5,567,4356,345,34,79,78,53,5,5,6,47,567,56,7,46,345,34,5,36,47,57]

    val m11 = IFM.fromList(mk [12,456,79,78,56,6])
    val m11not = IFM.fromList(mk [12,79,78,310,56])

    val m1 = IFM.fromList l1
    val m2 = IFM.fromList l2

    val m3 = IFM.plus(m1,m2)

    fun test s true = print ("OK : " ^ s ^ "\n")
      | test s false = print ("ERROR : " ^ s ^ "\n")

    val test1 = test "test1" (IFM.list(m3) === IFM.list(IFM.fromList(l1@l2)))

    val test2 = test "test2" (IFM.lookup m1 6 = SOME "6")
    val test3 = test "test3" (IFM.lookup m1 9 = NONE)

    val test4 = test "test4" (IFM.lookup m3 4356 = SOME "4356'")

    val test5 = test "test5" (IFM.lookup m3 35 = SOME "35")

    fun sum [] = 0
      | sum (x::xs) = x + sum xs

    fun remdubs ([],a:int list) = a
      | remdubs (x::xs,a) = remdubs(xs, if member a x then a else x::a)

    val test10 = test "test10" (sum (IFM.dom m1) = sum (remdubs (map #1 l1,[])))

    val test11 = test "test11" (IFM.lookup (IFM.add(2222,"2222''",m1)) 2222 = SOME "2222''")
    val test12 = test "test12" (IFM.lookup (IFM.add(234,"234''",m1)) 234 = SOME "234''")

    val test13 = test "test13" (not(Option.isSome(IFM.remove (328,m1))))
    val test14 = test "test14" (IFM.lookup (valOf(IFM.remove (345,m1))) 345 = NONE)
    val test15 = test "test15" (IFM.lookup (valOf(IFM.remove (345,m1))) 456 = SOME "456")

  end

structure Main = struct

structure M = IntFinMap

local
    val a = 16807.0
    val m = 2147483647.0
    fun nextrand seed = let val t = a*seed
			in t - m * real(floor(t/m))
			end
    fun newgenseed seed = ref (nextrand seed)
    fun random (seedref as ref seed) =
        (seedref := nextrand seed; seed / m)
    val seed = newgenseed 1223.0
in
    fun rnd () = floor (random seed * m)
end

fun mkL n =
    let fun loop (0,l) = l
          | loop (n,l) = loop (n-1,rnd()::l)
    in loop (n,nil)
    end

infix |>
fun x |> f = f x

fun main (name, args) =
    let val N = 5000
        val l1 = mkL N |> map (fn x => (x,~x))
        val l2 = mkL N |> map (fn x => (x,~x))

        fun doit () =
            let val x = l1 |> M.fromList
                val y = l2 |> M.fromList
                val z = M.plus (x, y)
                val s = M.Map (fn (k,v) => k+v) z
                val v = M.fold (op +) 0 s
            in if v <> 0 then raise Fail "err"
               else ()
            end
        fun repeat (0, f) = ()
          | repeat (n, f) = (f(); repeat (n-1, f))
    in print "Starting...\n"
     ; repeat (1000, doit)
     ; print "Done!\n"
     ; OS.Process.success
    end

end

val _ = Main.main (CommandLine.name(), CommandLine.arguments())
