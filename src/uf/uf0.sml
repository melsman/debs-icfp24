
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

structure Main = struct

fun doN n f = if n <= 0 then ()
              else (f (); doN (n-1) f)

open UF

fun main (name, arguments) =
    let val N = 100000
        val U = 200000
        val F = 500000
        val R = 20

        val rnd =
            let val rng = Random.newgenseed 1.37
                val g = Random.range (0,N-1)
            in fn () => g rng
            end

        fun doit () =
            let val elems = Vector.tabulate (N, uref)
                fun rndElem () = Vector.sub(elems,rnd())
            in doN U (fn () => union(rndElem(),rndElem()))
             ; doN F (fn () => find(rndElem()))
            end
    in print ("Starting [N=" ^ Int.toString N ^
              ", Unions=" ^ Int.toString U ^
              ", Finds=" ^ Int.toString F ^
              ", Repeats=" ^ Int.toString R ^
              "]\n")
     ; doN R doit
     ; print "Done.\n"
     ; OS.Process.success
    end

end
