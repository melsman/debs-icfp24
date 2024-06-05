(* This test works only for 32-bit implementations! *)


local 
  open Int32
in
val maxint : int32 = 2147483647
val minint = ~maxint -1

infix seq
fun e1 seq e2 = e2;
fun test t s = print (t ^ ": " ^ s ^ "<br>")
fun check true = "OK"
  | check false = "WRONG"

val _ = print "<h2>File int32_2.sml: More testing of structure Int32...</h2>"

val test0 = test "test0" (case maxInt
			    of SOME i => check(i=maxint)
			     | _ => "WRONG")
val test0a = test "test0a" (case minInt
			      of SOME i => check(i=minint)
			       | _ => "WRONG")
val test1 = test "test1" ((~minint seq "WRONG") handle Overflow => "OK")

val test2 = test "test2" ((abs minint seq "WRONG") handle Overflow => "OK")
val test3 = test "test3" ((maxint+1   seq "WRONG") handle Overflow => "OK")
val test4 = test "test4" ((minint-1   seq "WRONG") handle Overflow => "OK")

val test5 = test "test5" (if maxint =  0x7fffffff then "OK" else "WRONG")
val test6 = test "test6" (if maxint =  0x7FFFFFFF then "OK" else "WRONG")
val test7 = test "test7" (if minint = ~0x80000000 then "OK" else "WRONG")

val sum = (op+) : int * int -> int
val diff = (op-) : int * int -> int

val test8 = test "test8" ((sum (maxint,1)  seq "WRONG") handle Overflow => "OK")
val test9 = test "test9" ((diff (minint,1) seq "WRONG") handle Overflow => "OK")

val test10 = test "test10" ((minint * ~1 seq  "WRONG") handle Overflow => "OK")

val prod = (op * ) : int * int -> int

val test11 = test "test11" ((prod (minint,~1) seq "WRONG") handle Overflow => "OK")

fun checkDivMod i d =
  let val q = i div d
      val r = i mod d
  in 
      if (d * q + r = i) andalso
	  ((0 <= r andalso r < d) orelse (d < r andalso r <= 0))
      then "OK" else "WRONG: problems with div, mod"
  end;

val test12 = test "test12" (checkDivMod 23 10)
val test13 = test "test13" (checkDivMod ~23 10)
val test14 = test "test14" (checkDivMod 23 ~10)
val test15 = test "test15" (checkDivMod ~23 ~10)

val test16 = test "test16" (checkDivMod 100 10)
val test17 = test "test17" (checkDivMod ~100 10)
val test18 = test "test18" (checkDivMod 100 ~10)
val test19 = test "test19" (checkDivMod ~100 ~10)

val test20 = test "test20" (checkDivMod 100 1)
val test21 = test "test21" (checkDivMod 100 ~1)
val test22 = test "test22" (checkDivMod 0 1)
val test23 = test "test23" (checkDivMod 0 ~1)

val test24 = test "test24" ((100 div 0     seq  "WRONG") handle Div => "OK")
val test25 = test "test25" ((100 mod 0     seq  "WRONG") handle Div => "OK")
val test26 = test "test26" ((minint div ~1 seq  "WRONG") handle Overflow => "OK")


(* toInt *)
fun iftag yes no = 
  if Int.precision = SOME 31 then yes else no

val test27 = test "test27" ((toInt maxint seq (iftag "WRONG" "OK")) 
			    handle Overflow => iftag "OK" "WRONG")
val test27a = test "test27a" ((toInt (maxint-10) seq (iftag "WRONG" "OK")) 
			      handle Overflow => iftag "OK" "WRONG")
val test28 = test "test28" ((toInt minint seq (iftag "WRONG" "OK")) 
			    handle Overflow => iftag "OK" "WRONG")
val test28a = test "test28a" ((toInt (minint+10) seq (iftag "WRONG" "OK")) 
			      handle Overflow => iftag "OK" "WRONG")
val test29 = test "test29" ((check (SOME(toInt (maxint div 2)) = Option.map Int31.toInt Int31.maxInt)) 
			    handle Overflow => "EXN")
val test29a = test "test29a" ((check (SOME(toInt (minint div 2)) = Option.map Int31.toInt Int31.minInt)) 
			      handle Overflow => "EXN")

val _ = print "Test ended"
end
