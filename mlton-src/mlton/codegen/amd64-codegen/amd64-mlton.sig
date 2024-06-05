(* Copyright (C) 2019 Matthew Fluet.
 * Copyright (C) 1999-2007 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

signature AMD64_MLTON_STRUCTS =
  sig
    structure amd64MLtonBasic : AMD64_MLTON_BASIC
    structure amd64Liveness : AMD64_LIVENESS
    sharing amd64MLtonBasic.amd64 = amd64Liveness.amd64
  end

signature AMD64_MLTON =
  sig
    include AMD64_MLTON_STRUCTS
    include AMD64_MLTON_BASIC
    sharing amd64 = amd64MLtonBasic.amd64
    sharing amd64 = amd64Liveness.amd64
    sharing amd64.Label = Machine.Label
    sharing Machine = amd64MLtonBasic.Machine

    type transInfo = {addData : amd64.Assembly.t list -> unit,
                      live: amd64.Label.t -> amd64.Operand.t list,
                      liveInfo: amd64Liveness.LiveInfo.t}

    (* c call, and primitive assembly sequences. *)
    val ccall: {args: (amd64.Operand.t * amd64.Size.t) vector,
                func: RepType.t Machine.CFunction.t,
                return: {return: amd64.Label.t, size: int option} option,
                transInfo: transInfo} -> amd64.Block.t' AppendList.t
    val creturn: {dsts: (amd64.Operand.t * amd64.Size.t) vector,
                  frameInfo: amd64.FrameInfo.t option,
                  func: RepType.t Machine.CFunction.t,
                  label: amd64.Label.t, 
                  transInfo: transInfo} -> amd64.Block.t' AppendList.t
    val implementsPrim: RepType.t Machine.Prim.t -> bool
    val prim: {prim: RepType.t Machine.Prim.t,
               args: (amd64.Operand.t * amd64.Size.t) vector,
               dsts: (amd64.Operand.t * amd64.Size.t) vector,
               transInfo: transInfo} -> amd64.Block.t' AppendList.t
  end
