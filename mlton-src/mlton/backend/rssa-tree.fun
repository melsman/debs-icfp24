(* Copyright (C) 2009,2016-2017,2019-2021 Matthew Fluet.
 * Copyright (C) 1999-2008 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

functor RssaTree (S: RSSA_TREE_STRUCTS): RSSA_TREE =
struct

open S

local
   open Runtime
in
   structure CFunction = CFunction
   structure GCField = GCField
end

fun constrain (ty: Type.t): Layout.t =
   let
      open Layout
   in
      if !Control.showTypes
         then seq [str ": ", Type.layout ty]
      else empty
   end

structure Operand =
   struct
      datatype t =
         Cast of t * Type.t
       | Const of Const.t
       | GCState
       | Offset of {base: t,
                    offset: Bytes.t,
                    ty: Type.t}
       | ObjptrTycon of ObjptrTycon.t
       | Runtime of GCField.t
       | SequenceOffset of {base: t,
                            index: t,
                            offset: Bytes.t,
                            scale: Scale.t,
                            ty: Type.t}
       | Var of {var: Var.t,
                 ty: Type.t}

      val null = Const Const.null

      val word = Const o Const.word
      val deWord =
         fn Const (Const.Word w) => SOME w
          | _ => NONE

      val one = word o WordX.one
      val zero = word o WordX.zero

      fun bool b = (if b then one else zero) WordSize.bool

      val ty =
         fn Cast (_, ty) => ty
          | Const c => Type.ofConst c
          | GCState => Type.gcState ()
          | Offset {ty, ...} => ty
          | ObjptrTycon _ => Type.objptrHeader ()
          | Runtime z => Type.ofGCField z
          | SequenceOffset {ty, ...} => ty
          | Var {ty, ...} => ty

      fun layout (z: t): Layout.t =
         let
            open Layout 
         in
            case z of
               Cast (z, ty) =>
                  seq [str "Cast ", tuple [layout z, Type.layout ty]]
             | Const c => seq [Const.layout c, constrain (ty z)]
             | GCState => str "<GCState>"
             | Offset {base, offset, ty} =>
                  seq [str (concat ["O", Type.name ty, " "]),
                       tuple [layout base, Bytes.layout offset],
                       constrain ty]
             | ObjptrTycon opt => ObjptrTycon.layout opt
             | Runtime r => GCField.layout r
             | SequenceOffset {base, index, offset, scale, ty} =>
                  seq [str (concat ["X", Type.name ty, " "]),
                       tuple [layout base, layout index, Scale.layout scale,
                              Bytes.layout offset]]
             | Var {var, ...} => Var.layout var
         end

      fun cast (z: t, t: Type.t): t =
         if Type.equals (t, ty z)
            then z
         else Cast (z, t)

      val cast = Trace.trace2 ("Rssa.Operand.cast", layout, Type.layout, layout) cast

      fun 'a foldVars (z: t, a: 'a, f: Var.t * 'a -> 'a): 'a =
         case z of
            Cast (z, _) => foldVars (z, a, f)
          | Offset {base, ...} => foldVars (base, a, f)
          | SequenceOffset {base, index, ...} =>
               foldVars (index, foldVars (base, a, f), f)
          | Var {var, ...} => f (var, a)
          | _ => a

      fun replace (z: t, {const: Const.t -> t,
                          var: {ty: Type.t, var: Var.t} -> t}): t =
         let
            fun loop (z: t): t =
               case z of
                  Cast (t, ty) => Cast (loop t, ty)
                | Const c => const c
                | Offset {base, offset, ty} =>
                     Offset {base = loop base,
                             offset = offset,
                             ty = ty}
                | SequenceOffset {base, index, offset, scale, ty} =>
                     SequenceOffset {base = loop base,
                                  index = loop index,
                                  offset = offset,
                                  scale = scale,
                                  ty = ty}
                | Var x_ty => var x_ty
                | _ => z
         in
            loop z
         end
   end

structure Object =
   struct
      local
         structure S = Object (open S
                               structure Use = Operand)
      in
         open S
      end

      fun replace' (s, {const, var}) =
         replace (s, {use = fn oper => Operand.replace (oper, {const = const,
                                                               var = var})})
   end

structure Statement =
   struct
      datatype t =
         Bind of {dst: Var.t * Type.t,
                  pinned: bool,
                  src: Operand.t}
       | Move of {dst: Operand.t,
                  src: Operand.t}
       | Object of {dst: Var.t * Type.t,
                    obj: Object.t}
       | PrimApp of {args: Operand.t vector,
                     dst: (Var.t * Type.t) option,
                     prim: Type.t Prim.t}
       | Profile of ProfileExp.t
       | SetExnStackLocal
       | SetExnStackSlot
       | SetHandler of Label.t
       | SetSlotExnStack

      fun 'a foldDefUse (s, a: 'a, {def: Var.t * Type.t * 'a -> 'a,
                                    use: Var.t * 'a -> 'a}): 'a =
         let
            fun useOperand (z: Operand.t, a) = Operand.foldVars (z, a, use)
         in
            case s of
               Bind {dst = (x, t), src, ...} => def (x, t, useOperand (src, a))
             | Move {dst, src} => useOperand (src, useOperand (dst, a))
             | Object {dst = (x, t), obj} => def (x, t, Object.foldUse (obj, a, useOperand))
             | PrimApp {dst, args, ...} =>
                  Vector.fold (args,
                               Option.fold (dst, a, fn ((x, t), a) =>
                                            def (x, t, a)),
                               useOperand)
             | Profile _ => a
             | SetExnStackLocal => a
             | SetExnStackSlot => a
             | SetHandler _ => a
             | SetSlotExnStack => a
         end

      fun foreachDefUse (s: t, {def, use}) =
         foldDefUse (s, (), {def = fn (x, t, ()) => def (x, t),
                             use = use o #1})

      fun 'a foldDef (s: t, a: 'a, f: Var.t * Type.t * 'a -> 'a): 'a =
         foldDefUse (s, a, {def = f, use = #2})

      fun foreachDef (s:t , f: Var.t * Type.t -> unit) =
         foldDef (s, (), fn (x, t, ()) => f (x, t))

      fun 'a foldUse (s: t, a: 'a, f: Var.t * 'a -> 'a) =
         foldDefUse (s, a, {def = #3, use = f})

      fun foreachUse (s, f) = foldUse (s, (), f o #1)

      fun replace (s: t, fs as {const: Const.t -> Operand.t,
                                var: {ty: Type.t, var: Var.t} -> Operand.t}): t =
         let
            fun oper (z: Operand.t): Operand.t =
               Operand.replace (z, {const = const, var = var})
         in
            case s of
               Bind {dst, pinned, src} =>
                  Bind {dst = dst,
                        pinned = pinned,
                        src = oper src}
             | Move {dst, src} => Move {dst = oper dst, src = oper src}
             | Object {dst, obj} => Object {dst = dst, obj = Object.replace' (obj, fs)}
             | PrimApp {args, dst, prim} =>
                  PrimApp {args = Vector.map (args, oper),
                           dst = dst,
                           prim = prim}
             | Profile _ => s
             | SetExnStackLocal => s
             | SetExnStackSlot => s
             | SetHandler _ => s
             | SetSlotExnStack => s
         end

      val layout =
         let
            open Layout
         in
            fn Bind {dst = (x, t), src, ...} =>
                  mayAlign
                  [seq [Var.layout x, constrain t],
                   indent (seq [str "= ", Operand.layout src], 2)]
             | Move {dst, src} =>
                  mayAlign
                  [Operand.layout dst,
                   indent (seq [str ":= ", Operand.layout src], 2)]
             | Object {dst = (x, t), obj} =>
                  mayAlign
                  [seq [Var.layout x, constrain t],
                   indent (seq [str "= ", Object.layout obj], 2)]
             | PrimApp {dst, prim, args, ...} =>
                  mayAlign
                  [case dst of
                      NONE => seq [str "_", constrain (Type.unit)]
                    | SOME (x, t) => seq [Var.layout x, constrain t],
                   indent (seq [str "= ", Prim.layout prim, str " ",
                                Vector.layout Operand.layout args],
                           2)]
             | Profile e => ProfileExp.layout e
             | SetExnStackLocal => str "SetExnStackLocal"
             | SetExnStackSlot => str "SetExnStackSlot "
             | SetHandler l => seq [str "SetHandler ", Label.layout l]
             | SetSlotExnStack => str "SetSlotExnStack "
         end

      val toString = Layout.toString o layout

      fun clear (s: t) =
         foreachDef (s, Var.clear o #1)

      fun resize (src: Operand.t, dstTy: Type.t): Operand.t * t list =
         let
            val srcTy = Operand.ty src

            val (src, srcTy, ssSrc, dstTy, finishDst) =
               case (Type.deReal srcTy, Type.deReal dstTy) of
                  (NONE, NONE) => 
                     (src, srcTy, [], dstTy, fn dst => (dst, []))
                | (SOME rs, NONE) =>
                     let
                        val ws = WordSize.fromBits (RealSize.bits rs)
                        val tmp = Var.newNoname ()
                        val tmpTy = Type.word ws
                     in
                        (Operand.Var {ty = tmpTy, var = tmp},
                         tmpTy,
                         [PrimApp {args = Vector.new1 src,
                                   dst = SOME (tmp, tmpTy),
                                   prim = Prim.Real_castToWord (rs, ws)}],
                         dstTy, fn dst => (dst, []))
                     end
                | (NONE, SOME rs) =>
                     let
                        val ws = WordSize.fromBits (RealSize.bits rs)
                        val tmp = Var.newNoname ()
                        val tmpTy = Type.real rs
                     in
                        (src, srcTy, [],
                         Type.word ws,
                         fn dst =>
                         (Operand.Var {ty = tmpTy, var = tmp},
                          [PrimApp {args = Vector.new1 dst,
                                    dst = SOME (tmp, tmpTy),
                                    prim = Prim.Word_castToReal (ws, rs)}]))
                     end
                | (SOME _, SOME _) =>
                     (src, srcTy, [], dstTy, fn dst => (dst, []))

            val srcW = Type.width srcTy
            val dstW = Type.width dstTy

            val (dst, ssConv) =
               if Bits.equals (srcW, dstW)
                  then (Operand.cast (src, dstTy), [])
               else let
                       val tmp = Var.newNoname ()
                       val tmpTy = dstTy
                    in
                       (Operand.Var {ty = tmpTy, var = tmp},
                        [PrimApp {args = Vector.new1 src,
                                  dst = SOME (tmp, tmpTy),
                                  prim = (Prim.Word_extdToWord
                                          (WordSize.fromBits srcW, 
                                           WordSize.fromBits dstW, 
                                           {signed = false}))}])
                    end

            val (dst, ssDst) = finishDst dst
         in
            (dst, ssSrc @ ssConv @ ssDst)
         end
   end

structure Switch =
   struct
      local
         structure S = Switch (open S
                               structure Use = Operand)
      in
         open S
      end

      fun replace' (s, {const, label, var}) =
         replace (s, {label = label,
                      use = fn oper => Operand.replace (oper, {const = const,
                                                               var = var})})
   end

structure Transfer =
   struct
      datatype t =
         CCall of {args: Operand.t vector,
                   func: Type.t CFunction.t,
                   return: Label.t option}
       | Call of {args: Operand.t vector,
                  func: Func.t,
                  return: Return.t}
       | Goto of {args: Operand.t vector,
                  dst: Label.t}
       | Raise of Operand.t vector
       | Return of Operand.t vector
       | Switch of Switch.t

      fun layout t =
         let
            open Layout
         in
            case t of
               CCall {args, func, return} =>
                  seq [str "CCall ",
                       record [("args", Vector.layout Operand.layout args),
                               ("func", CFunction.layout (func, Type.layout)),
                               ("return", Option.layout Label.layout return)]]
             | Call {args, func, return} =>
                  seq [Func.layout func, str " ",
                       Vector.layout Operand.layout args,
                       str " ", Return.layout return]
             | Goto {dst, args} =>
                  seq [Label.layout dst, str " ",
                       Vector.layout Operand.layout args]
             | Raise xs => seq [str "raise ", Vector.layout Operand.layout xs]
             | Return xs => seq [str "return ", Vector.layout Operand.layout xs]
             | Switch s => Switch.layout s
         end

      fun bug () =
         CCall {args = (Vector.new1
                        (Operand.Const
                         (Const.string "control shouldn't reach here"))),
                func = Type.BuiltInCFunction.bug (),
                return = NONE}

      fun foreachFunc (t, f : Func.t -> unit) : unit =
         case t of
            Call {func, ...} => f func
          | _ => ()

      fun 'a foldLabelUse (t, a: 'a,
                           {label: Label.t * 'a -> 'a,
                            use: Var.t * 'a -> 'a}): 'a =
         let
            fun useOperand (z, a) = Operand.foldVars (z, a, use)
            fun useOperands (zs: Operand.t vector, a) =
               Vector.fold (zs, a, useOperand)
         in
            case t of
               CCall {args, return, ...} =>
                  useOperands (args,
                               case return of
                                  NONE => a
                                | SOME l => label (l, a))
             | Call {args, return, ...} =>
                  useOperands (args, Return.foldLabel (return, a, label))
             | Goto {args, dst, ...} => label (dst, useOperands (args, a))
             | Raise zs => useOperands (zs, a)
             | Return zs => useOperands (zs, a)
             | Switch s => Switch.foldLabelUse (s, a, {label = label,
                                                       use = useOperand})
         end

      fun foreachLabelUse (t, {label, use}) =
         foldLabelUse (t, (), {label = label o #1,
                               use = use o #1})

      fun foldLabel (t, a, f) = foldLabelUse (t, a, {label = f,
                                                     use = #2})

      fun foreachLabel (t, f) = foldLabel (t, (), f o #1)

      fun foldUse (t, a, f) = foldLabelUse (t, a, {label = #2,
                                                   use = f})

      fun foreachUse (t, f) = foldUse (t, (), f o #1)

      local
         fun make (i, ws) = WordX.fromIntInf (i, ws)
      in
         fun ifBoolE (test, expect, {falsee, truee}) =
            let
               val ws =
                  case Type.deWord (Operand.ty test) of
                     NONE => Error.bug "RssaTree.Transfer.ifBoolE: non-Word test type"
                   | SOME ws => ws
               val make = fn i => make (i, ws)
            in
               Switch (Switch.T
                       {cases = Vector.new2 ((make 0, falsee), (make 1, truee)),
                        default = NONE,
                        expect = Option.map (expect, fn expect => if expect then make 1 else make 0),
                        size = ws,
                        test = test})
            end
         fun ifBool (test, branches) = ifBoolE (test, NONE, branches)
         fun ifZero (test, {falsee, truee}) =
            let
               val ws =
                  case Type.deWord (Operand.ty test) of
                     NONE => Error.bug "RssaTree.Transfer.ifZero: non-Word test type"
                   | SOME ws => ws
               val make = fn i => make (i, ws)
            in
               Switch (Switch.T
                       {cases = Vector.new1 (make 0, truee),
                        default = SOME falsee,
                        expect = NONE,
                        size = ws,
                        test = test})
            end
      end

      fun replace (t: t, fs as {const: Const.t -> Operand.t,
                                label: Label.t -> Label.t,
                                var: {ty: Type.t, var: Var.t} -> Operand.t}): t =
         let
            fun oper z = Operand.replace (z, {const = const, var = var})
            fun opers zs = Vector.map (zs, oper)
         in
            case t of
               CCall {args, func, return} =>
                  CCall {args = opers args,
                         func = func,
                         return = Option.map (return, label)}
             | Call {args, func, return} =>
                  Call {args = opers args,
                        func = func,
                        return = Return.map (return, label)}
             | Goto {args, dst} =>
                  Goto {args = opers args,
                        dst = label dst}
             | Raise zs => Raise (opers zs)
             | Return zs => Return (opers zs)
             | Switch s => Switch (Switch.replace' (s, fs))
         end
      fun replaceLabels (s, label) =
         replace (s, {const = Operand.Const,
                      label = label,
                      var = Operand.Var})
   end

structure Kind =
   struct
      datatype t =
         Cont of {handler: Handler.t}
       | CReturn of {func: Type.t CFunction.t}
       | Handler
       | Jump

      fun isJump k =
         case k of
            Jump => true
          | _ => false

      fun layout k =
         let
            open Layout
         in
            case k of
               Cont {handler} =>
                  seq [str "Cont ",
                       record [("handler", Handler.layout handler)]]
             | CReturn {func} =>
                  seq [str "CReturn ",
                       record [("func", CFunction.layout (func, Type.layout))]]
             | Handler => str "Handler"
             | Jump => str "Jump"
         end

      datatype frameStyle = None | OffsetsAndSize | SizeOnly
      fun frameStyle (k: t): frameStyle =
         case k of
            Cont _ => OffsetsAndSize
          | CReturn {func, ...} =>
               if CFunction.mayGC func
                  then OffsetsAndSize
               else if !Control.profile = Control.ProfileNone
                       then None
                    else SizeOnly
          | Handler => SizeOnly
          | Jump => None
   end

local
   open Layout
in
   fun layoutFormals (xts: (Var.t * Type.t) vector) =
      Vector.layout (fn (x, t) =>
                    seq [Var.layout x,
                         if !Control.showTypes
                            then seq [str ": ", Type.layout t]
                         else empty])
      xts
end

structure Block =
   struct
      datatype t =
         T of {args: (Var.t * Type.t) vector,
               kind: Kind.t,
               label: Label.t,
               statements: Statement.t vector,
               transfer: Transfer.t}

      local
         fun make f (T r) = f r
      in
         val kind = make #kind
         val label = make #label
      end

      fun clear (T {args, label, statements, ...}) =
         (Vector.foreach (args, Var.clear o #1)
          ; Label.clear label
          ; Vector.foreach (statements, Statement.clear))

      fun layout (T {args, kind, label, statements, transfer, ...}) =
         let
            open Layout
         in
            align [seq [Label.layout label, str " ",
                        Vector.layout (fn (x, t) =>
                                       if !Control.showTypes
                                          then seq [Var.layout x, str ": ",
                                                    Type.layout t]
                                       else Var.layout x) args,
                        str " ", Kind.layout kind, str " = "],
                   indent (align
                           [align
                            (Vector.toListMap (statements, Statement.layout)),
                            Transfer.layout transfer],
                           2)]
         end

      fun foreachDef (T {args, statements, ...}, f) =
         (Vector.foreach (args, f)
          ; Vector.foreach (statements, fn s => Statement.foreachDef (s, f)))

      fun foreachUse (T {statements, transfer, ...}, f) =
         (Vector.foreach (statements, fn s => Statement.foreachUse (s, f))
          ; Transfer.foreachUse (transfer, f))
   end

structure Function =
   struct
      datatype t = T of {args: (Var.t * Type.t) vector,
                         blocks: Block.t vector,
                         name: Func.t,
                         raises: Type.t vector option,
                         returns: Type.t vector option,
                         start: Label.t}

      local
         fun make f (T r) = f r
      in
         val blocks = make #blocks
         val name = make #name
      end

      fun dest (T r) = r
      val new = T

      fun clear (T {name, args, blocks, ...}) =
         (Func.clear name
          ; Vector.foreach (args, Var.clear o #1)
          ; Vector.foreach (blocks, Block.clear))

      fun layoutHeader (T {args, name, raises, returns, start, ...}): Layout.t =
         let
            open Layout
         in
            seq [str "fun ", Func.layout name,
                 str " ", layoutFormals args,
                 if !Control.showTypes
                    then seq [str ": ",
                              record [("raises",
                                       Option.layout
                                       (Vector.layout Type.layout) raises),
                                      ("returns",
                                       Option.layout
                                       (Vector.layout Type.layout) returns)]]
                 else empty,
                 str " = ", Label.layout start, str " ()"]
         end

      fun layouts (f as T {blocks, ...}, output) =
         (output (layoutHeader f)
          ; Vector.foreach (blocks, fn b =>
                            output (Layout.indent (Block.layout b, 2))))

      fun layout (f as T {blocks, ...}) =
         let
            open Layout
         in
            align [layoutHeader f,
                   indent (align (Vector.toListMap (blocks, Block.layout)), 2)]
         end

      fun foreachDef (T {args, blocks, ...}, f) =
         (Vector.foreach (args, f)
          ; (Vector.foreach (blocks, fn b => Block.foreachDef (b, f))))

      fun foreachUse (T {blocks, ...}, f) =
         Vector.foreach (blocks, fn b => Block.foreachUse (b, f))

      fun dfs (T {blocks, start, ...}, v) =
         let
            val numBlocks = Vector.length blocks
            val {get = labelIndex, set = setLabelIndex, rem, ...} =
               Property.getSetOnce (Label.plist,
                                    Property.initRaise ("index", Label.layout))
            val _ = Vector.foreachi (blocks, fn (i, Block.T {label, ...}) =>
                                     setLabelIndex (label, i))
            val visited = Array.array (numBlocks, false)
            fun visit (l: Label.t): unit =
               let
                  val i = labelIndex l
               in
                  if Array.sub (visited, i)
                     then ()
                  else
                     let
                        val _ = Array.update (visited, i, true)
                        val b as Block.T {transfer, ...} =
                           Vector.sub (blocks, i)
                        val v' = v b
                        val _ = Transfer.foreachLabel (transfer, visit)
                        val _ = v' ()
                     in
                        ()
                     end
               end
            val _ = visit start
            val _ = Vector.foreach (blocks, rem o Block.label)
         in
            ()
         end

      structure Graph = DirectedGraph
      structure Node = Graph.Node

      fun overlayGraph (T {blocks, ...}) =
         let
            open Dot
            val g = Graph.new ()
            fun newNode () = Graph.newNode g
            val {get = labelNode, rem = remLabelNode, ...} =
               Property.get
               (Label.plist, Property.initFun (fn _ => newNode ()))
            val {get = nodeInfo: unit Node.t -> Block.t,
                 set = setNodeInfo, ...} =
               Property.getSetOnce
               (Node.plist, Property.initRaise ("info", Node.layout))
            val () =
               Vector.foreach
               (blocks, fn b as Block.T {label, ...}=>
                setNodeInfo (labelNode label, b))
            fun destroyLabelNode () =
               Vector.foreach (blocks, remLabelNode o Block.label)
         in
            (g, {labelNode = labelNode,
                 destroyLabelNode = destroyLabelNode,
                 nodeInfo = nodeInfo})
         end

      fun dominatorTree (t as T {blocks, start, ...}): Block.t Tree.t =
         let
            val (g, {labelNode, destroyLabelNode, nodeInfo}) = overlayGraph t
            val _ =
               Vector.foreach
               (blocks, fn Block.T {transfer, label = from, ...} =>
                Transfer.foreachLabel
                (transfer, fn to =>
                 ignore (Graph.addEdge (g, {from = labelNode from, to = labelNode to}))))
         in
            Graph.dominatorTree (g, {root = labelNode start, nodeValue = nodeInfo})
            before destroyLabelNode ()
         end

      fun loopForest (t as T {blocks, start, ...}, predicate) =
         let
            val (g, {labelNode, destroyLabelNode, nodeInfo}) = overlayGraph t
            val _ =
               Vector.foreach
               (blocks, fn from as Block.T {transfer, label, ...} =>
                Transfer.foreachLabel
                (transfer, fn to =>
                 if predicate (from, (nodeInfo o labelNode) to)
                    then ignore (Graph.addEdge (g, {from = labelNode label, to = labelNode to}))
                    else ignore (Graph.addEdge (g, {from = labelNode start, to = labelNode to}))))
         in
            Graph.loopForestSteensgaard (g, {root = labelNode start, nodeValue = nodeInfo})
            before destroyLabelNode ()
         end

      fun dropProfile (f: t): t =
         let
            val {args, blocks, name, raises, returns, start} = dest f
            val blocks =
               Vector.map
               (blocks, fn Block.T {args, kind, label, statements, transfer} =>
                Block.T {args = args,
                         kind = kind,
                         label = label,
                         statements = Vector.keepAll
                                      (statements,
                                       fn Statement.Profile _ => false
                                        | _ => true),
                         transfer = transfer})
         in
            new {args = args,
                 blocks = blocks,
                 name = name,
                 raises = raises,
                 returns = returns,
                 start = start}
         end

      fun shuffle (f: t): t =
         let
            val {args, blocks, name, raises, returns, start} = dest f
            val blocks = Array.fromVector blocks
            val () = Array.shuffle blocks
         in
            new {args = args,
                 blocks = Array.toVector blocks,
                 name = name,
                 raises = raises,
                 returns = returns,
                 start = start}
         end
   end

structure Program =
   struct
      datatype t =
         T of {functions: Function.t list,
               handlesSignals: bool,
               main: Function.t,
               objectTypes: ObjectType.t vector,
               profileInfo: {sourceMaps: SourceMaps.t,
                             getFrameSourceSeqIndex: Label.t -> int option} option,
               statics: {dst: Var.t * Type.t, obj: Object.t} vector}

      fun clear (T {functions, main, statics, ...}) =
         (List.foreach (functions, Function.clear)
          ; Function.clear main
          ; Vector.foreach (statics, Statement.clear o Statement.Object))

      fun layouts (T {functions, main, objectTypes, statics, ...},
                   output': Layout.t -> unit): unit =
         let
            open Layout
            val output = output'
         in
            output (str "\nObjectTypes:")
            ; Vector.foreachi (objectTypes, fn (i, ty) =>
                               output (seq [str "opt_", Int.layout i,
                                            str " = ", ObjectType.layout ty]))
            ; output (str "\nStatics:")
            ; Vector.foreach (statics, output o Statement.layout o Statement.Object)
            ; output (str "\nMain:")
            ; Function.layouts (main, output)
            ; output (str "\nFunctions:")
            ; List.foreach (functions, fn f => Function.layouts (f, output))
         end

      val toFile = {display = Control.Layouts layouts, style = Control.ML, suffix = "rssa"}

      fun layoutStats (program as T {functions, main, objectTypes, statics, ...}) =
         let
            val numStatements = ref 0
            val numBlocks = ref 0
            val _ =
               List.foreach
               (main::functions, fn f =>
                let
                   val {blocks, ...} = Function.dest f
                in
                   Vector.foreach
                   (blocks, fn Block.T {statements, ...} =>
                    (Int.inc numBlocks
                     ; numStatements := !numStatements + Vector.length statements))
                end)
            val numFunctions = 1 + List.length functions
            val numObjectTypes = Vector.length objectTypes
            val numStatics = Vector.length statics
            open Layout
         in
            align
            [seq [Control.sizeMessage ("rssa program", program)],
             seq [str "num functions in program = ", Int.layout numFunctions],
             seq [str "num blocks in program = ", Int.layout (!numBlocks)],
             seq [str "num statements in program = ", Int.layout (!numStatements)],
             seq [str "num object types in program = ", Int.layout (numObjectTypes)],
             seq [str "num statics in program = ", Int.layout numStatics]]
         end

      fun dropProfile (T {functions, handlesSignals, main, objectTypes, statics, ...}) =
         (Control.profile := Control.ProfileNone
          ; T {functions = List.map (functions, Function.dropProfile),
               handlesSignals = handlesSignals,
               main = Function.dropProfile main,
               objectTypes = objectTypes,
               profileInfo = NONE,
               statics = statics})
      (* quell unused warning *)
      val _ = dropProfile

      fun dfs (p, v) =
         let
            val T {functions, main, ...} = p
            val functions = Vector.fromList (main::functions)
            val numFunctions = Vector.length functions
            val {get = funcIndex, set = setFuncIndex, rem, ...} =
               Property.getSetOnce (Func.plist,
                                    Property.initRaise ("index", Func.layout))
            val _ = Vector.foreachi (functions, fn (i, f) =>
                                     setFuncIndex (#name (Function.dest f), i))
            val visited = Array.array (numFunctions, false)
            fun visit (f: Func.t): unit =
               let
                  val i = funcIndex f
               in
                  if Array.sub (visited, i)
                     then ()
                  else
                     let
                        val _ = Array.update (visited, i, true)
                        val f = Vector.sub (functions, i)
                        val v' = v f
                        val _ = Function.dfs 
                                (f, fn Block.T {transfer, ...} =>
                                 (Transfer.foreachFunc (transfer, visit)
                                  ; fn () => ()))
                        val _ = v' ()
                     in
                        ()
                     end
               end
            val _ = visit (Function.name main)
            val _ = Vector.foreach (functions, rem o Function.name)
         in
            ()
         end

      structure Labels = PowerSetLattice_ListSet(structure Element = Label)
      fun rflow (T {functions, main, ...}) =
         let
            val functions = main :: functions
            val table = HashTable.new {equals = Func.equals, hash = Func.hash}
            fun get f =
               HashTable.lookupOrInsert (table, f, fn () =>
                                         {raisesTo = Labels.empty (),
                                          returnsTo = Labels.empty ()})
            val raisesTo = #raisesTo o get
            val returnsTo = #returnsTo o get
            val empty = Labels.empty ()
            val _ =
               List.foreach
               (functions, fn f =>
                let
                   val {name, blocks, ...} = Function.dest f
                in
                   Vector.foreach
                   (blocks, fn Block.T {transfer, ...} =>
                    case transfer of
                       Transfer.Call {func, return, ...} =>
                          let
                             val (returns, raises) =
                                case return of
                                   Return.Dead => (empty, empty)
                                 | Return.NonTail {cont, handler, ...} =>
                                      (Labels.singleton cont,
                                       case handler of
                                          Handler.Caller => raisesTo name
                                        | Handler.Dead => empty
                                        | Handler.Handle hand => Labels.singleton hand)
                                 | Return.Tail => (returnsTo name, raisesTo name)
                          in
                             Labels.<= (returns, returnsTo func)
                             ; Labels.<= (raises, raisesTo func)
                          end
                     | _ => ())
                end)
         in
            fn f =>
            let
               val {raisesTo, returnsTo} = get f
            in
               {raisesTo = Labels.getElements raisesTo,
                returnsTo = Labels.getElements returnsTo}
            end
         end

      fun orderFunctions (p as T {handlesSignals, objectTypes, profileInfo, statics, ...}) =
         let
            val functions = ref []
            val () =
               dfs
               (p, fn f =>
                let
                   val {args, name, raises, returns, start, ...} =
                      Function.dest f
                   val blocks = ref []
                   val () =
                      Function.dfs
                      (f, fn b =>
                       (List.push (blocks, b)
                        ; fn () => ()))
                   val f = Function.new {args = args,
                                         blocks = Vector.fromListRev (!blocks),
                                         name = name,
                                         raises = raises,
                                         returns = returns,
                                         start = start}
                in
                   List.push (functions, f)
                   ; fn () => ()
                end)
            val (main, functions) =
               case List.rev (!functions) of
                  main::functions => (main, functions)
                | _ => Error.bug "Rssa.orderFunctions: main/functions"
         in
            T {functions = functions,
               handlesSignals = handlesSignals,
               main = main,
               objectTypes = objectTypes,
               profileInfo = profileInfo,
               statics = statics}
         end

      fun shuffle (T {functions, handlesSignals, main, objectTypes, profileInfo, statics}) =
         let
            val functions = Array.fromListMap (functions, Function.shuffle)
            val () = Array.shuffle functions
            val p = T {functions = Array.toList functions,
                       handlesSignals = handlesSignals,
                       main = Function.shuffle main,
                       objectTypes = objectTypes,
                       profileInfo = profileInfo,
                       statics = statics}
         in
            p
         end
   end
end
