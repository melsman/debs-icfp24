fun tak (x,y,z) =
   if not (y < x)
      then z
   else tak (tak (x - 1, y, z),
	     tak (y - 1, z, x),
	     tak (z - 1, x, y))

val rec f =
   fn 0 => ()
    | n => (tak (18,12,6); f (n-1))

structure Main =
   struct
      fun doit () = f 5000
   end

val _ = Main.doit()