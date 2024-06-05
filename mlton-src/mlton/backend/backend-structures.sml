
structure BackendAtoms = BackendAtoms (open Atoms)

structure Machine = Machine (open BackendAtoms)

structure Rssa = Rssa (open BackendAtoms)

structure Backend = Backend (structure Machine = Machine
                             structure Rssa = Rssa
                             fun funcToLabel f = f)

structure Ssa2ToRssa = Ssa2ToRssa (structure Rssa = Rssa
                                   structure Ssa2 = Ssa2)
