(* Internal representation of IntInf.int including conversion
   functions to be used in the Int/IntN/Word/WordN
   implementations. This signature, as well as its matching structure
   is declared before any of the Int/IntN/Word/WordN modules. mael
   2005-12-14 *)

signature INT_INF_REP =
  sig
      type intinf

      val fromInt    : int -> intinf
      val toInt      : intinf -> int

      val fromInt31  : int31 -> intinf
      val toInt31    : intinf -> int31

      val fromInt32  : int32 -> intinf
      val toInt32    : intinf -> int32

      val fromInt63  : int63 -> intinf
      val toInt63    : intinf -> int63

      val fromInt64  : int64 -> intinf
      val toInt64    : intinf -> int64

      val fromWord   : word -> intinf
      val fromWordX  : word -> intinf
      val toWord     : intinf -> word

      val fromWord8  : word8 -> intinf
      val fromWord8X : word8 -> intinf
      val toWord8    : intinf -> word8

      val fromWord31 : word31 -> intinf
      val fromWord31X : word31 -> intinf
      val toWord31   : intinf -> word31

      val fromWord32 : word32 -> intinf
      val fromWord32X : word32 -> intinf
      val toWord32   : intinf -> word32

      val fromWord63 : word63 -> intinf
      val fromWord63X : word63 -> intinf
      val toWord63   : intinf -> word63

      val fromWord64 : word64 -> intinf
      val fromWord64X : word64 -> intinf
      val toWord64   : intinf -> word64

      (* for overloading *)
      val +   : intinf * intinf -> intinf
      val -   : intinf * intinf -> intinf
      val *   : intinf * intinf -> intinf
      val ~   : intinf -> intinf
      val div : intinf * intinf -> intinf
      val mod : intinf * intinf -> intinf
      val abs : intinf -> intinf
      val <   : intinf * intinf -> bool
      val >   : intinf * intinf -> bool
      val <=  : intinf * intinf -> bool
      val >=  : intinf * intinf -> bool
  end
