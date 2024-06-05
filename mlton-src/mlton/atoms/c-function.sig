(* Copyright (C) 2009,2015,2019 Matthew Fluet.
 * Copyright (C) 2004-2006 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

signature C_FUNCTION_STRUCTS = 
   sig
      structure CType: C_TYPE
      structure SymbolScope: C_SYMBOL_SCOPE
   end

signature C_FUNCTION = 
   sig
      include C_FUNCTION_STRUCTS

      structure Convention:
         sig
            datatype t = Cdecl | Stdcall

            val layout: t -> Layout.t
            val toString: t -> string
         end

      structure Kind:
         sig
            datatype t =
               Impure
             | Pure
             | Runtime of {(* bytesNeeded = SOME i means that the i'th
                            * argument to the function is a word that
                            * specifies the number of bytes that must be
                            * free in order for the C function to succeed.
                            * Limit check insertion is responsible for
                            * making sure that the bytesNeeded is available.
                            *)
                           bytesNeeded: int option,
                           (* ensuresBytesFree = SOME i means that the
                            * i'th argument to the function is a word
                            * that specifies a number of bytes that
                            * must be free when the C function (which
                            * must have mayGC = true) returns.
                            * Limit check insertion is responsible for
                            * setting the ensuresBytesFree argument to
                            * cover the allocation(s) in the return
                            * block(s).
                            *)
                           ensuresBytesFree: int option,
                           mayGC: bool,
                           maySwitchThreadsFrom: bool,
                           maySwitchThreadsTo: bool,
                           modifiesFrontier: bool,
                           readsStackTop: bool,
                           writesStackTop: bool}

            val impure: t
            val pure: t
            val reentrant: t
            val runtimeDefault: t

            val layout: t -> Layout.t
            val toString: t -> string

            val bytesNeeded: t -> int option
            val ensuresBytesFree: t -> int option
            val mayGC: t -> bool
            val maySwitchThreadsFrom: t -> bool
            val maySwitchThreadsTo: t -> bool
            val modifiesFrontier: t -> bool
            val readsStackTop: t -> bool
            val writesStackTop: t -> bool
         end

      structure Target:
         sig
            datatype t = Direct of string | Indirect

            val layout: t -> Layout.t
            val toString: t -> string
         end

      datatype 'a t = T of {args: 'a vector,
                            convention: Convention.t,
                            inline: bool,
                            kind: Kind.t,
                            prototype: CType.t vector * CType.t option,
                            return: 'a,
                            symbolScope: SymbolScope.t,
                            (* target = Indirect means that the 0'th
                             * argument to the function is a word
                              * that specifies the target.
                             *)
                            target: Target.t}

      val args: 'a t -> 'a vector
      val bytesNeeded: 'a t -> int option
      val convention: 'a t -> Convention.t
      val ensuresBytesFree: 'a t -> int option
      val equals: 'a t * 'a t -> bool
      val cPointerType: 'a t -> string
      val cPrototype: 'a t -> string
      val isOk: 'a t * {isUnit: 'a -> bool} -> bool
      val layout: 'a t * ('a -> Layout.t) -> Layout.t
      val map: 'a t * ('a -> 'b) -> 'b t
      val mayGC: 'a t -> bool
      val maySwitchThreadsFrom: 'a t -> bool
      val maySwitchThreadsTo: 'a t -> bool
      val modifiesFrontier: 'a t -> bool
      val parse: 'a Parse.t -> 'a t Parse.t
      val prototype: 'a t -> CType.t vector * CType.t option
      val readsStackTop: 'a t -> bool
      val return: 'a t -> 'a
      val symbolScope: 'a t -> SymbolScope.t
      val target: 'a t -> Target.t
      val writesStackTop: 'a t -> bool
      val vanilla: {args: 'a vector,
                    name: string,
                    prototype: CType.t vector * CType.t option,
                    return: 'a} -> 'a t
   end
