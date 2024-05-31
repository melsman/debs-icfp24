structure Word32 : WORD where type word = Word.word =
  struct
    structure W = Word
    type word = W.word
    val wordSize = 32
    val toLarge = W.toLarge
    val high : W.word = 0wx7FFFFFFF00000000
    val low : W.word = 0wxFFFFFFFF
    fun signextend w = if w > 0wx7FFFFFFF then W.orb(high,w) else w
    fun norm w = W.andb(w,low)
    fun toLargeX a = W.toLargeX (signextend a)
    val toLargeWord = toLarge
    val toLargeWordX = toLargeX
    fun fromLarge a = norm (W.fromLarge a)
    val fromLargeWord = fromLarge
    val toLargeInt = W.toLargeInt
    fun toLargeIntX a = W.toLargeIntX (signextend a)
    fun fromLargeInt a = norm (W.fromLargeInt a)
    val toInt = W.toInt
    fun toIntX a = W.toIntX (signextend a)
    fun fromInt a = norm (W.fromInt a)

    val andb = W.andb
    val orb = W.orb
    val xorb = W.xorb
    val notb = norm o W.notb
    val << = fn (a,b) => norm (W.<< (a,b))
    val >> = fn (a,b) => W.>> (a,b)
    val ~>> = fn (x,y) => norm (W.~>> (signextend x,y))

    val op+ = fn a => norm (W.+ a)
    val op- = fn a => norm (W.- a)
    val op* = fn a => norm (W.* a)
    val op div = W.div
    val op mod = W.mod

    val compare = W.compare
    val op< = W.<
    val op<= = W.<=
    val op> = W.>
    val op>= = W.>=

    val ~ = fn a => norm (W.~ a)
    val min = W.min
    val max = W.max

    val fmt = W.fmt
    val toString = W.toString
    fun scan r gc s = let val v = W.scan r gc s in Option.map (fn (w,r) => if W.andb(w,high) = W.fromInt 0 then (w,r) else raise Overflow) v end
    fun fromString s = let val v = W.fromString s in Option.map (fn w => if W.andb(w,high) = W.fromInt 0 then w else raise Overflow) v end
  end
