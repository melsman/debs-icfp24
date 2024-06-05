infix  6  + -
infixr 5  ::
infix  4  = <> > >= < <=
infix  3  := o
type 'a ref = 'a ref

fun op = (x: ''a, y: ''a): bool = prim ("=", (x, y))

fun print (s:string) : unit = prim("printStringML", s)
fun printNum (n:int):unit = prim("printNum",n)

local
  exception E of int
in
  exception F
  exception G
  val y =
    case G of
      E x => (print "E matched: "; printNum x; print "\n")
    | F => print "F matched\n"
    | _ => print "OK-Something else...\n"

end;
