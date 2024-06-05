structure Timestamp: TIMESTAMP =
  struct
    type stamp = int

    val r = ref 0
    fun new() = (r := !r + 1; !r)

    fun stamp2int i = i

    fun print i = (*"$" ^*) Int.toString i
  end;
