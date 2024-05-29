
structure Main = struct

local
    val a = 0w16807
    val seed = ref 0w223
in
fun rnd m =
    let val t = (!seed * a) mod (Word.fromInt m)
    in seed := t
     ; Word.toInt t
    end
end

fun main (name, arguments) =
    let val N = 20000
        val s1 = String.concatWith "+" (List.tabulate (N, fn _ => Int.toString (rnd 10)))
        val s2 = String.concatWith "-" (List.tabulate (2*N, fn _ => Int.toString (rnd 5)))

        val s0 = "343+45+3+2+34+4+3+34+34+34+234+234+23+4+234+234+234+23+4-3-34-4-234-42-234-234-234-3^2*23+one-two"

        val s = s1 ^ "+" ^ s2

        val s = s ^ "+" ^ s0 ^ "-" ^ s ^ ";"

        fun bench s n a =
            if n <= 0 then a
            else let val r = Calc.parseString s
                 in case r of
                        SOME v => bench s (n-1) (a+v)
                      | NONE => raise Fail "parse error"
                 end

        (*val t = Time.now()*)
        val res = bench s 20 0

        (* val () = print ("Time: " ^ Time.toString (Time.-(Time.now(),t)) ^ "\n") *)

    in print ("Ok: " ^ Int.toString res ^ "\n")
     ; OS.Process.success
    end

end
