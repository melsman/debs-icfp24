(* Copyright (C) 2009,2014,2017,2019-2020 Matthew Fluet.
 * Copyright (C) 1999-2007 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

signature CONST_STRUCTS = 
   sig
      structure CSymbol: C_SYMBOL
      structure RealX: REAL_X
      structure WordX: WORD_X
      structure WordXVector: WORD_X_VECTOR
      sharing WordX = RealX.WordX = WordXVector.WordX
   end

signature CONST = 
   sig
      include CONST_STRUCTS

      structure IntInfRep:
         sig
            datatype t = Big of WordXVector.t | Small of WordX.t
            val bigToIntInf: WordXVector.t -> IntInf.t option
            val fromIntInf: IntInf.t -> t
            val smallToIntInf: WordX.t -> IntInf.t option
         end

      datatype t =
         CSymbol of CSymbol.t
       | IntInf of IntInf.t
       | Null
       | Real of RealX.t
       | Word of WordX.t
       | WordVector of WordXVector.t

      val csymbol: CSymbol.t -> t
      val deWord: t -> WordX.t
      val deWordOpt: t -> WordX.t option
      val equals: t * t -> bool
      val intInf: IntInf.t -> t
      val hash: t -> word
      val layout: t -> Layout.t
      val null: t
      val parse: t Parse.t
      val real: RealX.t -> t
      val string: string -> t
      val toString: t -> string
      val word: WordX.t -> t
      val wordVector: WordXVector.t -> t
   end
