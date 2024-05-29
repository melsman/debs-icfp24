structure Main =
  struct
    val name = "Logic"

    exception Done

    fun testit strm = Data.exists(fn Z => Data.solution2 Z (fn () => raise Done))
	  handle Done => TextIO.output(strm, "yes\n")

    fun doit () = Data.exists(fn Z => Data.solution2 Z (fn () => raise Done))
	  handle Done => print "Yes\n"

    fun repeat (0, f) = ()
      | repeat (n, f) = (f(); repeat (n-1, f))

    fun main (name, args) =
        ( repeat (5, doit)
        ; OS.Process.success
        )

  end
