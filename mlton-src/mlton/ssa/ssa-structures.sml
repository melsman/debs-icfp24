
structure Ssa = Ssa (open Atoms)

structure Ssa2 = Ssa2 (open Atoms)

structure SsaToSsa2 = SsaToSsa2 (structure Ssa = Ssa
                                 structure Ssa2 = Ssa2)
