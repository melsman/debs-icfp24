(* This test works only for 64-bit implementations! *)

local fun pow2 n : int = if n < 1 then 1 else 2 * pow2(n-1)
in val maxInt63 : int = pow2 61 + (pow2 61 - 1)
   val minInt63 : int = ~maxInt63 - 1
   fun maxInt64 () : int = pow2 62 + (pow2 62 - 1)
   fun minInt64 () : int = ~(maxInt64()) - 1
end

local fun pow2 n : LargeInt.int = if n < 1 then 1 else 2 * pow2(n-1)
in val maxInt63L : LargeInt.int = pow2 61 + (pow2 61 - 1)
   val minInt63L : LargeInt.int = ~maxInt63L - 1
   fun maxInt64L () : LargeInt.int = pow2 62 + (pow2 62 - 1)
   fun minInt64L () : LargeInt.int = ~(maxInt64L()) - 1
end

local open Int
in
val maxint : int =
  case precision
    of SOME 64 => maxInt64()
     | SOME 63 => maxInt63
     | SOME i => raise Fail ("maxint.SOME(" ^ Int.toString i ^ ")")
     | NONE => raise Fail "maxint.NONE"
val minint = ~maxint -1

fun tagging () = precision = SOME 63

infix seq
fun e1 seq e2 = e2;
fun test t s = print (t ^ ": " ^ s ^ "\n")
fun check true = "OK"
  | check false = "ERR"
fun test' t b = test t (check b)
fun test'' t f = test t ((check (f())) handle _ => "EXN")

val test1 = test "test1" ((~minint seq "WRONG") handle Overflow => "OK")

val test2 = test "test2" ((abs minint seq "WRONG") handle Overflow => "OK")
val test3 = test "test3" ((maxint+1   seq "WRONG") handle Overflow => "OK")
val test4 = test "test4" ((minint-1   seq "WRONG") handle Overflow => "OK")

val test5 = test "test5" (case precision
			    of SOME 64 => ((if maxint = 2 * 0x3fffffffffffffff + 1 then "OK" else "WRONG")
					   handle Overflow => "EXN")
			     | SOME 63 => if maxint = 0x3fffffffffffffff then "OK" else "WRONG"
			     | _ => "WRONG")
val test6 = test "test6" (case precision
			    of SOME 64 => ((if maxint = 2 * 0x3FFFFFFFFFFFFFFF + 1 then "OK" else "WRONG")
					   handle Overflow => "EXN")
			     | SOME 63 => if maxint = 0x3FFFFFFFFFFFFFFF then "OK" else "WRONG"
			     | _ => "WRONG")
val test7 = test "test7" (case precision
			    of SOME 64 => ((if minint = 2 * ~0x4000000000000000 then "OK" else "WRONG")
					   handle Overflow => "EXN")
			     | SOME 63 => if minint = ~0x4000000000000000 then "OK" else "WRONG"
			     | _ => "WRONG")

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
(*      printVal i seq TextIO.output(TextIO.stdOut, " ");
      printVal d seq TextIO.output(TextIO.stdOut, "   "); *)
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

val test35 = test' "test35" (toLarge ~1 = ~1)
val test36 = test' "test36" (toLarge 1 = 1)
val test37 = test' "test37" (toLarge 0 = 0)
val test38 = test' "test38" (tagging() andalso (toLarge maxint = maxInt63L)
			     orelse (toLarge maxint = maxInt64L()))
val test39 = test' "test39" (tagging() andalso (toLarge minint = minInt63L)
			     orelse (toLarge minint = minInt64L()))

val test40 = test'' "test40" (fn _ => fromLarge(toLarge ~1) = ~1)
val test41 = test'' "test41" (fn _ => fromLarge(toLarge maxint) = maxint)
val test42 = test'' "test42" (fn _ => fromLarge(toLarge 0) = 0)
val test42 = test'' "test42" (fn _ => fromLarge(toLarge minint) = minint)

val test43 = test "test43" ((fromLarge(Int64.toLarge(Int64.+(Int64.fromLarge(toLarge maxint), 1))) seq "WRONG")
                            handle Overflow => "OK")
val test44 = test "test44" ((fromLarge(Int64.toLarge(Int64.-(Int64.fromLarge(toLarge minint), 1))) seq "WRONG")
                            handle Overflow => "OK")
val test45 = test "test45" ((fromLarge(Int64.toLarge(valOf Int64.maxInt)) seq (if tagging() then "WRONG"
                                                                               else "OK"))
			    handle Overflow => if tagging() then "OK" else "WRONG")
val test46 = test "test46" ((fromLarge(Int64.toLarge(valOf Int64.minInt)) seq (if tagging() then "WRONG"
                                                                               else "OK"))
			    handle Overflow => if tagging() then "OK" else "WRONG")
end
