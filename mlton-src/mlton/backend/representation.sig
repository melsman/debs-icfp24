(* Copyright (C) 2009,2019-2020 Matthew Fluet.
 * Copyright (C) 1999-2007 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

signature REPRESENTATION_STRUCTS = 
   sig
      structure Rssa: RSSA
      structure Ssa2: SSA2
      sharing Rssa.Prod = Ssa2.Prod
      sharing Rssa.RealSize = Ssa2.RealSize
      sharing Rssa.WordSize = Ssa2.WordSize
   end

signature REPRESENTATION = 
   sig
      include REPRESENTATION_STRUCTS

      val compute:
         Ssa2.Program.t
         -> {diagnostic: unit -> unit,
             genCase: {cases: {con: Ssa2.Con.t,
                               dst: Rssa.Label.t,
                               dstHasArg: bool} vector,
                       default: Rssa.Label.t option,
                       test: unit -> Rssa.Operand.t,
                       tycon: Ssa2.Tycon.t} -> (Rssa.Statement.t list
                                                * Rssa.Transfer.t
                                                * Rssa.Block.t list),
             object: {args: Ssa2.Var.t vector,
                      con: Ssa2.Con.t option,
                      dst: Rssa.Var.t * Rssa.Type.t,
                      objectTy: Ssa2.Type.t,
                      oper: Ssa2.Var.t -> Rssa.Operand.t} -> Rssa.Statement.t list,
             objectTypes: (Rssa.ObjptrTycon.t * Rssa.ObjectType.t) vector,
             select: {base: Rssa.Operand.t Ssa2.Base.t,
                      baseTy: Ssa2.Type.t,
                      dst: Rssa.Var.t * Rssa.Type.t,
                      offset: int} -> Rssa.Statement.t list,
             sequence: {args: Ssa2.Var.t vector vector,
                        dst: Rssa.Var.t * Rssa.Type.t,
                        sequenceTy: Ssa2.Type.t,
                        oper: Ssa2.Var.t -> Rssa.Operand.t} -> Rssa.Statement.t list,
             toRtype: Ssa2.Type.t -> Rssa.Type.t option,
             update: {base: Rssa.Operand.t Ssa2.Base.t,
                      baseTy: Ssa2.Type.t,
                      offset: int,
                      value: Rssa.Operand.t} -> Rssa.Statement.t list}
   end
