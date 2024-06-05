(* Copyright (C) 2009,2011,2017,2019-2020 Matthew Fluet.
 * Copyright (C) 1999-2006 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

functor CommonSubexp (S: SSA_TRANSFORM_STRUCTS): SSA_TRANSFORM = 
struct

open S

open Exp Transfer

fun transform (Program.T {globals, datatypes, functions, main}) =
   let
      (* Keep track of control-flow specific cse's,
       * arguments, and in-degree of blocks.
       *)
      val {get = labelInfo: Label.t -> {add: (Var.t * Exp.t) list ref,
                                        args: (Var.t * Type.t) vector,
                                        inDeg: int ref},
           set = setLabelInfo, ...} =
         Property.getSetOnce (Label.plist,
                              Property.initRaise ("info", Label.layout))
      (* Keep track of a total ordering on variables. *)
      val {get = varIndex : Var.t -> int, set = setVarIndex, ...} =
         Property.getSetOnce (Var.plist,
                              Property.initRaise ("varIndex", Var.layout))
      val setVarIndex =
         let
            val c = Counter.generator 0
         in
            fn x => setVarIndex (x, c ())
         end
      (* Keep track of the replacements of variables. *)
      val {get = replace: Var.t -> Var.t option, set = setReplace, ...} =
         Property.getSetOnce (Var.plist, Property.initConst NONE)
      (* Keep track of the variable that holds the length of arrays (and
       * vectors and strings).
       *)
      val {get = getLength: Var.t -> Var.t option, set = setLength, ...} =
         Property.getSetOnce (Var.plist, Property.initConst NONE)
      fun canonVar x =
         case replace x of
            NONE => x
          | SOME y => y
      fun canonVars xs = Vector.map (xs, canonVar)
      (* Canonicalize an Exp.
       * Replace vars with their replacements.
       * Put commutative arguments in canonical order.
       *)
      fun canon (e: Exp.t): Exp.t =
         case e of
            ConApp {con, args} =>
               ConApp {con = con, args = canonVars args}
          | Const _ => e
          | PrimApp {prim, targs, args} =>
               let
                  fun doit args =
                     PrimApp {prim = prim,
                              targs = targs,
                              args = args}
                  val args = canonVars args
                  fun arg i = Vector.sub (args, i)
                  fun canon2 () =
                     let
                        val a0 = arg 0
                        val a1 = arg 1
                     in
                        if varIndex a0 >= varIndex a1
                           then (a0, a1)
                        else (a1, a0)
                     end
               in
                  if Prim.isCommutative prim
                     then doit (Vector.new2 (canon2 ()))
                  else
                     if (case prim of
                            Prim.IntInf_add => true
                          | Prim.IntInf_andb => true
                          | Prim.IntInf_gcd => true
                          | Prim.IntInf_mul => true
                          | Prim.IntInf_orb => true
                          | Prim.IntInf_xorb => true
                          | _ => false)
                        then
                           let
                              val (a0, a1) = canon2 ()
                           in doit (Vector.new3 (a0, a1, arg 2))
                           end
                     else doit args
               end
          | Select {tuple, offset} => Select {tuple = canonVar tuple,
                                              offset = offset}
          | Tuple xs => Tuple (canonVars xs)
          | Var x => Var (canonVar x)
          | _ => e

      (* Keep a hash table of canonicalized Exps that are in scope. *)
      val table: (Exp.t, Var.t) HashTable.t =
         HashTable.new {hash = Exp.hash, equals = Exp.equals}
      fun lookup (var, exp) =
         HashTable.lookupOrInsert
         (table, exp, fn () => var)

      fun doitStatements (statements, remove) =
         Vector.keepAllMap
         (statements,
          fn Statement.T {var, ty, exp} =>
          let
             val exp = canon exp
             fun keep () = SOME (Statement.T {var = var,
                                              ty = ty,
                                              exp = exp})
          in
             case var of
                NONE => keep ()
              | SOME var =>
                   let
                      val _ = setVarIndex var
                      fun replace var' =
                         (setReplace (var, SOME var'); NONE)
                      fun doit () =
                         let
                            val var' = lookup (var, exp)
                         in
                            if Var.equals(var, var')
                              then (List.push (remove, (exp, var'))
                                    ; keep ())
                              else replace var'
                         end
                   in
                      case exp of
                         PrimApp ({args, prim, ...}) =>
                            let
                               fun arg () = Vector.first args
                               fun knownLength var' =
                                  let
                                     val _ = setLength (var, SOME var')
                                  in
                                     keep ()
                                  end
                               fun conv () =
                                  case getLength (arg ()) of
                                     NONE => keep ()
                                   | SOME var' => knownLength var'
                               fun length () =
                                  case getLength (arg ()) of
                                     NONE => doit ()
                                   | SOME var' => replace var'
                            in
                               case prim of
                                  Prim.Array_alloc _ => knownLength (arg ())
                                | Prim.Array_length => length ()
                                | Prim.Array_toArray => conv ()
                                | Prim.Array_toVector => conv ()
                                | Prim.Vector_length => length ()
                                | _ => if Prim.isFunctional prim
                                          then doit ()
                                       else keep ()
                            end
                       | _ => doit ()
                   end
          end)

      (* All of the globals are in scope, and never go out of scope. *)
      val globals = doitStatements (globals, ref [])

      fun doitTree tree =
         let
            val blocks = ref []
            fun loop (Tree.T (Block.T {args, label,
                                       statements, transfer},
                              children)): unit =
               let
                 fun diag s =
                   Control.diagnostics
                   (fn display =>
                    let open Layout
                    in
                      display (seq [Label.layout label, str ": ", str s])
                    end)
                  val _ = diag "started"
                  val remove = ref []
                  val {add, ...} = labelInfo label
                  val _ = Control.diagnostics
                          (fn display =>
                           let open Layout
                           in
                              display (seq [str "add: ",
                                            List.layout (fn (var,exp) =>
                                                         seq [Var.layout var,
                                                              str ": ",
                                                              Exp.layout exp]) (!add)])
                           end)
                  val _ = List.foreach
                          (!add, fn (var, exp) =>
                           let
                             val var' = lookup (var, exp)
                             val _ = if Var.equals(var, var')
                                       then List.push (remove, (exp, var'))
                                       else ()
                           in
                             ()
                           end)
                  val _ = diag "added"
                  val _ =
                     Vector.foreach
                     (args, fn (var, _) => setVarIndex var)
                  val statements =
                     doitStatements (statements, remove)
                  val _ = diag "statements"
                  val transfer = Transfer.replaceVar (transfer, canonVar)
                  val transfer =
                     case transfer of
                        Goto {dst, args} =>
                           let
                              val {args = args', inDeg, ...} = labelInfo dst
                           in
                              if !inDeg = 1
                                 then (Vector.foreach2
                                       (args, args', fn (var, (var', _)) =>
                                        setReplace (var', SOME var))
                                       ; transfer)
                              else transfer
                           end
                      | _ => transfer
                  val _ = diag "transfer"
                  val block = Block.T {args = args,
                                       label = label,
                                       statements = statements,
                                       transfer = transfer}
                  val _ = List.push (blocks, block)
                  val _ = Vector.foreach (children, loop)
                  val _ = diag "children"
                  val _ = Control.diagnostics
                          (fn display =>
                           let open Layout
                           in
                              display (seq [str "remove: ",
                                            List.layout (fn (exp, var) =>
                                                         seq [Var.layout var,
                                                              str ": ",
                                                              Exp.layout exp]) (!remove)])
                           end)
                  val _ = List.foreach
                          (!remove, fn (exp, var) =>
                           HashTable.removeWhen
                           (table, exp, fn var' =>
                            Var.equals (var, var')))
                  val _ = diag "removed"
               in
                  ()
               end
            val _ =
              Control.diagnostics
              (fn display =>
               let open Layout
               in
                 display (seq [str "starting loop"])
               end)
            val _ = loop tree
            val _ =
              Control.diagnostics
              (fn display =>
               let open Layout
               in
                 display (seq [str "finished loop"])
               end)
         in
            Vector.fromList (!blocks)
         end
      val shrink = shrinkFunction {globals = globals}
      val functions =
         List.revMap
         (functions, fn f =>
          let
             val {args, blocks, mayInline, name, raises, returns, start} =
                Function.dest f
             val _ =
                Vector.foreach
                (args, fn (var, _) => setVarIndex var)
             val _ =
                Vector.foreach
                (blocks, fn Block.T {label, args, ...} =>
                 (setLabelInfo (label, {add = ref [],
                                        args = args,
                                        inDeg = ref 0})))
             val _ =
                Vector.foreach
                (blocks, fn Block.T {transfer, ...} =>
                 Transfer.foreachLabel (transfer, fn label' =>
                                        Int.inc (#inDeg (labelInfo label'))))
             val blocks = doitTree (Function.dominatorTree f)
          in
             shrink (Function.new {args = args,
                                   blocks = blocks,
                                   mayInline = mayInline,
                                   name = name,
                                   raises = raises,
                                   returns = returns,
                                   start = start})
          end)
      val program =
         Program.T {datatypes = datatypes,
                    globals = globals,
                    functions = functions,
                    main = main}
      val _ = Program.clearTop program
   in
      program
   end

end
