(* Copyright (C) 2019-2021 Matthew Fluet.
 * Copyright (C) 1999-2007 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

signature ATOMS_STRUCTS =
   sig
   end

signature ATOMS' =
   sig
      include ATOMS_STRUCTS

      structure AdmitsEquality: ADMITS_EQUALITY
      structure Cases: CASES
      structure CFunction: C_FUNCTION
      structure CSymbol: C_SYMBOL
      structure CSymbolScope: C_SYMBOL_SCOPE
      structure CType: C_TYPE
      structure CharSize: CHAR_SIZE
      structure Con: CON
      structure Const: CONST
      structure Ffi: FFI
      structure Field: FIELD
      structure Func: FUNC
      structure Handler: HANDLER
      structure IntSize: INT_SIZE
      structure Label: LABEL
      structure Prim: PRIM
      structure Prod: PROD
      structure ProfileExp: PROFILE_EXP
      structure RealSize: REAL_SIZE
      structure RealX: REAL_X
      structure Record: RECORD
      structure Return: RETURN
      structure SortedRecord: RECORD
      structure SourceInfo: SOURCE_INFO
      structure SourceMaps: SOURCE_MAPS
      structure Symbol: SYMBOL
      structure Tycon: TYCON
      structure TyconKind: TYCON_KIND
      structure Tyvar: TYVAR
      structure Var: VAR 
      structure WordSize: WORD_SIZE
      structure WordX: WORD_X
      structure WordXVector: WORD_X_VECTOR

      sharing AdmitsEquality = Tycon.AdmitsEquality
      sharing CFunction = Ffi.CFunction = Prim.CFunction
      sharing CSymbol = Const.CSymbol
      sharing CSymbolScope = CFunction.SymbolScope = CSymbol.CSymbolScope
      sharing CType = CFunction.CType = CSymbol.CType = Ffi.CType = Prim.CType
      sharing CharSize = Tycon.CharSize
      sharing Con = Prim.Con
      sharing Const = Prim.Const
      sharing Field = Record.Field = SortedRecord.Field
      sharing Handler = Return.Handler
      sharing IntSize = Tycon.IntSize
      sharing Label = Handler.Label = Return.Label
      sharing RealSize = CType.RealSize = Prim.RealSize = RealX.RealSize
         = Tycon.RealSize
      sharing RealX = Const.RealX
      sharing SourceInfo = ProfileExp.SourceInfo
      sharing TyconKind = Tycon.Kind
      sharing WordSize = Cases.WordSize = CType.WordSize = Prim.WordSize
         = Tycon.WordSize = WordX.WordSize
      sharing WordX = Cases.WordX = Const.WordX = WordXVector.WordX
      sharing WordXVector = Const.WordXVector
   end

signature ATOMS =
   sig
      structure Atoms: ATOMS'

      include ATOMS'

      (* For each structure, like CFunction, I would like to write two sharing
       * constraints
       *   sharing Atoms = CFunction
       *   sharing CFunction = Atoms.CFunction
       * but I can't because of a bug in SML/NJ that reports "Sharing structure
       * with a descendent substructure".  So, I am forced to write out lots
       * of individual sharing constraints.  Blech.
       *)
      sharing AdmitsEquality = Atoms.AdmitsEquality
      sharing CFunction = Atoms.CFunction
      sharing CSymbol = Atoms.CSymbol
      sharing CSymbolScope = Atoms.CSymbolScope
      sharing CType = Atoms.CType
      sharing CharSize = Atoms.CharSize
      sharing Cases = Atoms.Cases
      sharing Con = Atoms.Con
      sharing Const = Atoms.Const
      sharing Ffi = Atoms.Ffi
      sharing Field = Atoms.Field
      sharing Func = Atoms.Func
      sharing Handler = Atoms.Handler
      sharing IntSize = Atoms.IntSize
      sharing Label = Atoms.Label
      sharing Prim = Atoms.Prim
      sharing Prod = Atoms.Prod
      sharing ProfileExp = Atoms.ProfileExp
      sharing RealSize = Atoms.RealSize
      sharing RealX = Atoms.RealX
      sharing Record = Atoms.Record
      sharing Return = Atoms.Return
      sharing SortedRecord = Atoms.SortedRecord
      sharing SourceInfo = Atoms.SourceInfo
      sharing SourceMaps = Atoms.SourceMaps
      sharing Symbol = Atoms.Symbol
      sharing Tycon = Atoms.Tycon
      sharing TyconKind = Atoms.TyconKind
      sharing Tyvar = Atoms.Tyvar
      sharing Var = Atoms.Var
      sharing WordSize = Atoms.WordSize
      sharing WordX = Atoms.WordX
      sharing WordXVector = Atoms.WordXVector
   end
