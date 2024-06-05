
structure Xml = Xml (open Atoms)

structure Sxml = Sxml (open Xml)

structure Monomorphise = Monomorphise (structure Xml = Xml
                                       structure Sxml = Sxml)
