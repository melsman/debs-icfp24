
local
structure UF = struct
  datatype 'a t0 = ECR of 'a * int
                 | PTR of 'a t
  withtype 'a t = 'a t0 ref

  fun find (p as ref (ECR _)) = p
    | find (p as ref (PTR (p' as ref (ECR _)))) = p'
    | find (p as ref (PTR (p' as ref (PTR p'')))) =
      (p := PTR p''; find p'')

  fun uref x = ref (ECR (x, 0))

  fun union (p, q) =
      let val p' = find p
          val q' = find q
      in if p' = q'
         then ()
         else (case (!p', !q') of
                   (ECR (pc, pr), ECR (qc, qr)) =>
                   if pr = qr
                   then (q' := ECR (qc, qr+1);
                         p' := PTR q')
                   else if pr < qr
                   then p' := PTR q'
                   else q':= PTR p'
                 | _ => raise Fail "union")
      end
end

(* Benchmarking *)

in
structure Main : sig val main : string * string list -> OS.Process.status end =
struct

fun doN n f = if n <= 0 then ()
              else (f (); doN (n-1) f)

open UF

fun main (name, arguments) =
    let val N = 100000
        val U = 200000
        val F = 500000
        val R = 20

        val a = 0w16807
        val b = 0w223

        val seed = ref b
        fun rnd () =
            let val t = a * !seed
            in seed := t ; Word.toIntX(t mod (Word.fromInt N))
            end

        fun sub (a,i) = Vector.sub(a,i)

(*        fun sub (a : 'a vector, i : int) : 'a = prim ("word_sub0", (a, i)) *)

        fun doit () =
            let val elems = Vector.tabulate (N, uref)
                fun rndElem () = sub(elems,rnd())
            in doN U (fn () => union(rndElem(),rndElem()))
             ; doN F (fn () => find(rndElem()))
            end
        fun pr s i = print (s ^ Int.toString i ^ "\n")
    in print "Starting..\n"
     ; pr "N=" N
     ; pr "Unions=" U
     ; pr "Finds=" F
     ; pr "Repeats=" R
     ; doN R doit
     ; print "Done.\n"
     ; OS.Process.success
    end

end
end
