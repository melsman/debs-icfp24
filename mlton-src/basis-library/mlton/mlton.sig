(* Copyright (C) 2013,2019,2022 Matthew Fluet.
 * Copyright (C) 1999-2007 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

signature MLTON =
   sig
      include MLTON_ROOT

      structure Array: MLTON_ARRAY
      structure BinIO: MLTON_BIN_IO
(*      structure CallStack: MLTON_CALL_STACK *)
      structure CharArray: MLTON_MONO_ARRAY
      structure CharVector: MLTON_MONO_VECTOR
      structure Cont: MLTON_CONT
      structure Exn: MLTON_EXN
      structure Finalizable: MLTON_FINALIZABLE
      structure GC: MLTON_GC
      structure IntInf: MLTON_INT_INF
      structure Itimer: MLTON_ITIMER
      structure LargeReal: MLTON_REAL
      structure LargeWord: MLTON_WORD
      structure Platform: MLTON_PLATFORM
      structure Pointer: MLTON_POINTER
      structure ProcEnv: MLTON_PROC_ENV
      structure Process: MLTON_PROCESS
      structure Profile: MLTON_PROFILE
(*      structure Ptrace: MLTON_PTRACE *)
      structure Random: MLTON_RANDOM 
      structure Real: MLTON_REAL
      structure Real32: sig
                           include MLTON_REAL
                           val castFromWord: Word32.word -> t
                           val castToWord: t -> Word32.word
                        end
      structure Real64: sig
                           include MLTON_REAL
                           val castFromWord: Word64.word -> Real64.real
                           val castToWord: Real64.real -> Word64.word
                        end
      structure Rlimit: MLTON_RLIMIT
      structure Rusage: MLTON_RUSAGE
      structure Signal: MLTON_SIGNAL
      structure Syslog: MLTON_SYSLOG
      structure TextIO: MLTON_TEXT_IO
      structure Thread: MLTON_THREAD
      structure Vector: MLTON_VECTOR
      structure Weak: MLTON_WEAK
      structure Word: MLTON_WORD
      structure Word8: MLTON_WORD
      structure Word16: MLTON_WORD
      structure Word32: MLTON_WORD
      structure Word64: MLTON_WORD
      structure Word8Array: MLTON_MONO_ARRAY
      structure Word8Vector: MLTON_MONO_VECTOR
      structure World: MLTON_WORLD
   end
