(* Copyright (C) 2009,2016-2017,2019-2020 Matthew Fluet.
 * Copyright (C) 1999-2008 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

functor RssaShrink (S: RSSA_SHRINK_STRUCTS): RSSA_SHRINK =
struct

open S

local
   open Prim
in
   structure ApplyArg = ApplyArg
   structure ApplyResult = ApplyResult
end

fun shrinkFunction {main: Function.t, statics: {dst: Var.t * Type.t, obj: Object.t} vector}:
   {main: unit -> Function.t, shrink: Function.t -> Function.t} =
   let
      val {get = varInfo: Var.t -> {occurrences: int ref,
                                    replace: Operand.t option ref}, ...} =
         Property.get
         (Var.plist, Property.initFun (fn _ => {occurrences = ref 0,
                                                replace = ref NONE}))
      fun visitVar x = Int.inc (#occurrences (varInfo x))
      fun replaceVar x =
         case !(#replace (varInfo x)) of
            NONE => Error.bug (concat ["RssaShrink.replaceVar ", Var.toString x])
          | SOME oper => oper
      fun setReplaceVar (x, oper) =
         #replace (varInfo x) := SOME oper
      fun dontReplaceVar (x: Var.t, t: Type.t): unit =
         setReplaceVar (x, Operand.Var {var = x, ty = t})
      val setReplaceVar = fn (x: Var.t, t: Type.t, z: Operand.t) =>
         let
            val z =
               if Type.equals (Operand.ty z, t)
                  then z
                  else Operand.Cast (z, t)
         in
            setReplaceVar (x, z)
         end
      val {get = labelInfo, set = setLabelInfo, ...} =
         Property.getSetOnce
         (Label.plist, Property.initRaise ("RssaShrink.labelInfo", Label.layout))
      fun visitLabel l = Int.inc (#occurrences (labelInfo l))
      fun replaceLabel l =
         case (! o #replace o labelInfo) l of
              SOME l' => l'
            | NONE => l
      fun elimBlock l =
         let
            val {inline, occurrences, replace, ...} = labelInfo l
         in
            !inline orelse 0 = !occurrences orelse isSome (!replace)
         end

      fun shrink (f: Function.t, clear): Function.t =
         let
            val {args, blocks, name, raises, returns, start} = Function.dest f

            val () =
               Vector.foreach
               (blocks, fn block as Block.T {label, ...} =>
                setLabelInfo (label, {block = block,
                                      inline = ref false,
                                      replace = ref NONE,
                                      occurrences = ref 0}))
            val () = visitLabel start
            val () =
               Vector.foreach
               (blocks, fn Block.T {statements, transfer, ...} =>
                (Vector.foreach
                 (statements, fn stmt =>
                  Statement.foreachUse (stmt, visitVar))
                 ; Transfer.foreachLabelUse (transfer,
                                             {label = visitLabel,
                                              use = visitVar})))
            val () =
               Vector.foreach
               (blocks, fn Block.T {args, kind, label, statements, transfer} =>
                case transfer of
                   Transfer.Goto {args = gotoArgs, dst, ...} =>
                      let
                         val {replace, ...} = labelInfo label
                         val {inline = dstInline,
                              occurrences = dstOccurrences, ...} = labelInfo dst
                      in
                         if Vector.isEmpty statements
                            andalso Kind.isJump kind
                            andalso Vector.equals
                                    (args, gotoArgs, fn ((x, _), oper) =>
                                     !(#occurrences (varInfo x)) = 1
                                     andalso
                                     (case oper of
                                         Operand.Var {var = x', ...} =>
                                            Var.equals (x, x')
                                       | _ => false))
                            then replace := SOME dst
                         else if 1 = !dstOccurrences
                            then dstInline := true
                         else ()
                      end
                 | _ => ())
            val () =
               Vector.foreach
               (blocks, fn Block.T {label, ...} =>
                let
                   val {replace, ...} = labelInfo label
                   fun loop (l, seen) =
                      case (! o #replace o labelInfo) l of
                         SOME l' =>
                            if List.exists (seen, fn l'' =>
                                            Label.equals (l'', l'))
                               then (replace := SOME l'
                                     ; #replace (labelInfo l') := NONE)
                               else loop (l', l'::seen)
                       | NONE => replace := (case seen of
                                                nil => NONE
                                              | _::nil => NONE
                                              | l'::_ => SOME l')
                in
                   loop (label, [label])
                end)

            fun loopFormals args = Vector.foreach (args, dontReplaceVar)
            fun loopStatement (s: Statement.t): Statement.t option =
               let
                  datatype z = datatype Statement.t
                  val s = Statement.replace (s, {const = Operand.Const,
                                                 var = replaceVar o #var})
                  fun keep () =
                     (Statement.foreachDef (s, dontReplaceVar)
                      ; SOME s)
               in
                  case s of
                     Bind {dst = (dst, dstTy), pinned, src} =>
                        if pinned
                           then keep ()
                        else
                           let
                              datatype z = datatype Operand.t
                              fun getSrc src =
                                 case src of
                                    Cast (src, _) => getSrc src
                                  | Const _ => SOME src
                                  | Var _ => SOME src
                                  | _ => NONE
                           in
                              case getSrc src of
                                 NONE => keep ()
                               | SOME src =>
                                    (setReplaceVar (dst, dstTy, src)
                                     ; NONE)
                           end
                   | PrimApp {args, dst, prim} =>
                        let
                           fun replace (z: Operand.t): Statement.t option =
                              (Option.app (dst, fn (x, t) =>
                                           setReplaceVar (x, t, z))
                               ; NONE)
                           datatype z = datatype Operand.t
                           fun getArg arg =
                              case arg of
                                 Cast (arg, _) => getArg arg
                               | Const c => SOME (ApplyArg.Const c)
                               | Var x => SOME (ApplyArg.Var x)
                               | _ => NONE
                           val applyArgs = Vector.toListKeepAllMap (args, getArg)
                           datatype z = datatype ApplyResult.t
                        in
                           if Vector.length args <> List.length applyArgs
                              then keep ()
                           else
                              case (Prim.apply
                                    (prim, applyArgs,
                                     fn ({var = x, ...}, {var = y, ...}) =>
                                     Var.equals (x, y))) of
                                 Apply (prim, args) =>
                                    let
                                       val args =
                                          Vector.fromListMap (args, Operand.Var)
                                       val () = Option.app (dst, dontReplaceVar)
                                    in
                                       SOME (PrimApp {args = args,
                                                      dst = dst,
                                                      prim = prim})
                                    end
                               | Bool b => replace (Operand.bool b)
                               | Const c => replace (Operand.Const c)
                               | Unknown => keep ()
                               | Var x => replace (Operand.Var x)
                        end
                | _ => keep ()
               end
            fun loopStatementsTransfer (statements: Statement.t vector, transfer: Transfer.t) =
               let
                  val stmts = ref []
                  fun loop (ss, t) =
                     let
                        val () = List.push (stmts, Vector.keepAllMap (ss, loopStatement))
                        val t = Transfer.replace (t, {const = Operand.Const,
                                                      label = replaceLabel,
                                                      var = replaceVar o #var})
                        fun done () = (Vector.concat (List.rev (!stmts)), t)
                     in
                        case t of
                           Transfer.Goto {args, dst} =>
                              let
                                 val {block, inline, ...} = labelInfo dst
                              in
                                 if !inline
                                    then let
                                            val Block.T {args = formals, statements, transfer, ...} =
                                               block
                                            val binds =
                                               Vector.map2
                                               (formals, args, fn (dst, src) =>
                                                Statement.Bind {dst = dst,
                                                                pinned = false,
                                                                src = src})
                                            val () = List.push (stmts, Vector.keepAllMap (binds, loopStatement))
                                         in
                                            loop (statements, transfer)
                                         end
                                    else done ()
                              end
                         | _ => done ()
                     end
               in
                  loop (statements, transfer)
               end

            val start = replaceLabel start
            val () = loopFormals args
            val blocks = ref []
            val () =
               Function.dfs
               (f, fn Block.T {args, kind, label, statements, transfer} =>
                let
                   val () =
                      if elimBlock label
                         then ()
                         else let
                                 val () = loopFormals args
                                 val (statements, transfer) =
                                    loopStatementsTransfer (statements, transfer)
                              in
                                 List.push (blocks,
                                            Block.T {args = args,
                                                     kind = kind,
                                                     label = label,
                                                     statements = statements,
                                                     transfer = transfer})
                              end
                in
                   fn () => ()
                end)
            val blocks = Vector.fromList (!blocks)
            val f = Function.new {args = args,
                                  blocks = blocks,
                                  name = name,
                                  raises = raises,
                                  returns = returns,
                                  start = start}
            val _ = if clear then Function.clear f else ()
         in
            f
         end
      val () = Vector.foreach (statics, dontReplaceVar o #dst)
      val main = shrink (main, false)
   in
      {main = fn () => (Function.clear main; main),
       shrink = fn f => shrink (f, true)}
   end

fun shrink (Program.T {functions, handlesSignals, main, objectTypes, profileInfo, statics}): Program.t =
   let
      val {main, shrink} = shrinkFunction {main = main, statics = statics}
      val functions = List.revMap (functions, shrink)
      val main = main ()
   in
      Program.T {functions = functions,
                 handlesSignals = handlesSignals,
                 main = main,
                 objectTypes = objectTypes,
                 profileInfo = profileInfo,
                 statics = statics}
   end

end
