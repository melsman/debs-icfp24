(* Copyright (C) 2015,2017,2019 Matthew Fluet
 * Copyright (C) 1999-2008 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

functor CoreML (S: CORE_ML_STRUCTS): CORE_ML = 
struct

open S

structure Field = Record.Field

fun maybeConstrain (x, t) =
   let
      open Layout
   in
      if !Control.showTypes
         then seq [x, str ": ", Type.layout t]
      else x
   end

fun layoutTargs (ts: Type.t vector) =
   let
      open Layout
   in
      if !Control.showTypes
         andalso 0 < Vector.length ts
         then list (Vector.toListMap (ts, Type.layout))
      else empty
   end

structure Pat =
   struct
      datatype t = T of {node: node,
                         ty: Type.t}
      and node =
         Con of {arg: t option,
                 con: Con.t,
                 targs: Type.t vector}
       | Const of unit -> Const.t
       | Layered of Var.t * t
       | List of t vector
       | Or of t vector
       | Record of t Record.t
       | Var of Var.t
       | Vector of t vector
       | Wild

      local
         fun make f (T r) = f r
      in
         val dest = make (fn {node, ty} => (node, ty))
         val node = make #node
         val ty = make #ty
      end

      fun make (n, t) = T {node = n, ty = t}

      fun layout p =
         let
            val t = ty p
            open Layout
         in
            case node p of
               Con {arg, con, targs} =>
                  seq [Con.layout con,
                       layoutTargs targs,
                       case arg of
                          NONE => empty
                        | SOME p => seq [str " ", layout p]]
             | Const f => Const.layout (f ())
             | Layered (x, p) =>
                  seq [maybeConstrain (Var.layout x, t), str " as ", layout p]
             | List ps => list (Vector.toListMap (ps, layout))
             | Or ps => list (Vector.toListMap (ps, layout))
             | Record r =>
                  let
                     val extra =
                        Vector.exists
                        (Type.deRecord t, fn (f, _) =>
                         Option.isNone (Record.peek (r, f)))
                  in
                     Record.layout
                     {extra = if extra then ", ..." else "",
                      layoutElt = layout,
                      layoutTuple = fn ps => tuple (Vector.toListMap (ps, layout)),
                      record = r,
                      separator = " = "}
                  end
             | Var x => maybeConstrain (Var.layout x, t)
             | Vector ps => vector (Vector.map (ps, layout))
             | Wild => str "_"
         end

      fun wild t = make (Wild, t)

      fun var (x, t) = make (Var x, t)

      fun tuple ps =
         if 1 = Vector.length ps
            then Vector.first ps
            else make (Record (Record.tuple ps), Type.tuple (Vector.map (ps, ty)))

      local
         fun bool c = make (Con {arg = NONE, con = c, targs = Vector.new0 ()},
                            Type.bool)
      in
         val falsee: t = bool Con.falsee
         val truee: t = bool Con.truee
      end

      fun isUnit (p: t): bool =
         case node p of
            Record r => Record.forall (r, fn _ => false)
          | _ => false

      fun isWild (p: t): bool =
         case node p of
            Wild => true
          | _ => false

      fun isRefutable (p: t): bool =
         case node p of
            Con _ => true
          | Const _ => true
          | Layered (_, p) => isRefutable p
          | List _ => true
          | Or ps => Vector.exists (ps, isRefutable)
          | Record r => Record.exists (r, isRefutable)
          | Var _ => false
          | Vector _ => true
          | Wild => false

      fun foreachVar (p: t, f: Var.t -> unit): unit =
         let
            fun loop (p: t): unit =
               case node p of
                  Con _ => ()
                | Const _ => ()
                | Layered (x, p) => (f x; loop p)
                | List ps => Vector.foreach (ps, loop)
                | Or ps => Vector.foreach (ps, loop)
                | Record r => Record.foreach (r, loop)
                | Var x => f x
                | Vector ps => Vector.foreach (ps, loop)
                | Wild => ()
         in
            loop p
         end
   end

structure NoMatch =
   struct
      datatype t = Impossible | RaiseAgain | RaiseBind | RaiseMatch
   end

datatype noMatch = datatype NoMatch.t

datatype dec =
   Datatype of {cons: {arg: Type.t option,
                       con: Con.t} vector,
                tycon: Tycon.t,
                tyvars: Tyvar.t vector} vector
 | Exception of {arg: Type.t option,
                 con: Con.t}
 | Fun of {decs: {lambda: lambda,
                  var: Var.t} vector,
           tyvars: unit -> Tyvar.t vector}
 | Val of {matchDiags: {nonexhaustiveExn: Control.Elaborate.DiagDI.t,
                        nonexhaustive: Control.Elaborate.DiagEIW.t,
                        redundant: Control.Elaborate.DiagEIW.t},
           rvbs: {lambda: lambda,
                  var: Var.t} vector,
           tyvars: unit -> Tyvar.t vector,
           vbs: {ctxt: unit -> Layout.t,
                 exp: exp,
                 layPat: unit -> Layout.t,
                 nest: string list,
                 pat: Pat.t,
                 regionPat: Region.t} vector}
and exp = Exp of {node: expNode,
                  ty: Type.t}
and expNode =
   App of exp * exp
  | Case of {ctxt: unit -> Layout.t,
             kind: string * string,
             nest: string list,
             matchDiags: {nonexhaustiveExn: Control.Elaborate.DiagDI.t,
                          nonexhaustive: Control.Elaborate.DiagEIW.t,
                          redundant: Control.Elaborate.DiagEIW.t},
             noMatch: noMatch,
             region: Region.t,
             rules: {exp: exp,
                     layPat: (unit -> Layout.t) option,
                     pat: Pat.t,
                     regionPat: Region.t} vector,
             test: exp}
  | Con of Con.t * Type.t vector
  | Const of unit -> Const.t
  | EnterLeave of exp * SourceInfo.t
  | Handle of {catch: Var.t * Type.t,
               handler: exp,
               try: exp}
  | Lambda of lambda
  | Let of dec vector * exp
  | List of exp vector
  | PrimApp of {args: exp vector,
                prim: Type.t Prim.t,
                targs: Type.t vector}
  | Raise of exp
  | Record of exp Record.t
  | Seq of exp vector
  | Var of (unit -> Var.t) * (unit -> Type.t vector)
  | Vector of exp vector
and lambda = Lam of {arg: Var.t,
                     argType: Type.t,
                     body: exp,
                     mayInline: bool}

local
   open Layout
in
   fun layoutTyvars (ts: Tyvar.t vector) =
      case Vector.length ts of
         0 => empty
       | 1 => seq [str " ", Tyvar.layout (Vector.sub (ts, 0))]
       | _ => seq [str " ", tuple (Vector.toListMap (ts, Tyvar.layout))]

   fun layoutConArg {arg, con} =
      seq [Con.layout con,
           case arg of
              NONE => empty
            | SOME t => seq [str " of ", Type.layout t]]

   fun layoutDec d =
      case d of
         Datatype v =>
            seq [str "datatype",
                 align
                 (Vector.toListMap
                  (v, fn {cons, tycon, tyvars} =>
                   seq [layoutTyvars tyvars,
                        str " ", Tycon.layout tycon, str " = ",
                        align
                        (separateLeft (Vector.toListMap (cons, layoutConArg),
                                       "| "))]))]
       | Exception ca =>
            seq [str "exception ", layoutConArg ca]
       | Fun {decs, tyvars, ...} => layoutFuns (tyvars, decs)
       | Val {rvbs, tyvars, vbs, ...} =>
            align [layoutFuns (tyvars, rvbs),
                   align (Vector.toListMap
                          (vbs, fn {exp, pat, ...} =>
                           seq [str "val",
                                mayAlign [seq [layoutTyvars (tyvars ()),
                                               str " ", Pat.layout pat,
                                               str " ="],
                                          layoutExp exp]]))]
   and layoutExp (Exp {node, ...}) =
      case node of
         App (e1, e2) => paren (seq [layoutExp e1, str " ", layoutExp e2])
       | Case {rules, test, ...} =>
            Pretty.casee {default = NONE,
                          rules = Vector.map (rules, fn {exp, pat, ...} =>
                                              (Pat.layout pat, layoutExp exp)),
                          test = layoutExp test}
       | Con (c, targs) => seq [Con.layout c, layoutTargs targs]
       | Const f => Const.layout (f ())
       | EnterLeave (e, si) =>
            seq [str "EnterLeave ",
                 tuple [layoutExp e, SourceInfo.layout si]]
       | Handle {catch, handler, try} =>
            Pretty.handlee {catch = Var.layout (#1 catch),
                            handler = layoutExp handler,
                            try = layoutExp try}
       | Lambda l => layoutLambda l
       | Let (ds, e) =>
            Pretty.lett (align (Vector.toListMap (ds, layoutDec)),
                         layoutExp e)
       | List es => list (Vector.toListMap (es, layoutExp))
       | PrimApp {args, prim, targs} =>
            Pretty.primApp {args = Vector.map (args, layoutExp),
                            prim = Prim.layout prim,
                            targs = Vector.map (targs, Type.layout)}
       | Raise e => Pretty.raisee (layoutExp e)
       | Record r =>
            Record.layout
            {extra = "",
             layoutElt = layoutExp,
             layoutTuple = fn es => tuple (Vector.toListMap (es, layoutExp)),
             record = r,
             separator = " = "}
       | Seq es => Pretty.seq (Vector.map (es, layoutExp))
       | Var (var, targs) => 
            if !Control.showTypes
               then let 
                       open Layout
                       val targs = targs ()
                    in
                       if Vector.isEmpty targs
                          then Var.layout (var ())
                       else seq [Var.layout (var ()), str " ",
                                 Vector.layout Type.layout targs]
                    end
            else Var.layout (var ())
       | Vector es => vector (Vector.map (es, layoutExp))
   and layoutFuns (tyvars, decs)  =
      if Vector.isEmpty decs
         then empty
      else
         align [seq [str "val rec", layoutTyvars (tyvars ())],
                indent (align (Vector.toListMap
                               (decs, fn {lambda as Lam {argType, body = Exp {ty = bodyType, ...}, ...}, var} =>
                                align [seq [maybeConstrain (Var.layout var, Type.arrow (argType, bodyType)), str " = "],
                                       indent (layoutLambda lambda, 3)])),
                        3)]
   and layoutLambda (Lam {arg, argType, body, ...}) =
      paren (align [seq [str "fn ", 
                         maybeConstrain (Var.layout arg, argType),
                         str " =>"],
                    layoutExp body])

   fun layoutExpWithType (exp as Exp {ty, ...}) =
      let
         val node = layoutExp exp
      in
         if !Control.showTypes
            then seq [node, str " : ", Type.layout ty]
         else node
      end
end

structure Lambda =
   struct
      datatype t = datatype lambda

      val make = Lam

      fun dest (Lam r) = r

      val bogus = make {arg = Var.newNoname (),
                        argType = Type.unit,
                        body = Exp {node = Seq (Vector.new0 ()),
                                    ty = Type.unit},
                        mayInline = true}
   end

structure Exp =
   struct
      type dec = dec
      type lambda = lambda
      datatype t = datatype exp
      datatype node = datatype expNode

      datatype noMatch = datatype noMatch

      val layout = layoutExp
      val layoutWithType = layoutExpWithType

      local
         fun make f (Exp r) = f r
      in
         val dest = make (fn {node, ty} => (node, ty))
         val node = make #node
         val ty = make #ty
      end

      fun make (n, t) = Exp {node = n,
                             ty = t}

      fun var (x: Var.t, ty: Type.t): t =
         make (Var (fn () => x, fn () => Vector.new0 ()), ty)

      fun isExpansive (e: t): bool =
         case node e of
            App (e1, e2) =>
               (case node e1 of
                   Con (c, _) => Con.equals (c, Con.reff) orelse isExpansive e2
                 | _ => true)
          | Case _ => true
          | Con _ => false
          | Const _ => false
          | EnterLeave _ => true
          | Handle _ => true
          | Lambda _ => false
          | Let _ => true
          | List es => Vector.exists (es, isExpansive)
          | PrimApp _ => true
          | Raise _ => true
          | Record r => Record.exists (r, isExpansive)
          | Seq _ => true
          | Var _ => false
          | Vector es => Vector.exists (es, isExpansive)

      fun tuple es =
         if 1 = Vector.length es
            then Vector.first es
         else make (Record (Record.tuple es),
                    Type.tuple (Vector.map (es, ty)))

      val unit = tuple (Vector.new0 ())

      local
         fun bool c = make (Con (c, Vector.new0 ()), Type.bool)
      in
         val falsee: t = bool Con.falsee
         val truee: t = bool Con.truee
      end

      fun lambda (l as Lam {argType, body, ...}) =
         make (Lambda l, Type.arrow (argType, ty body))

      fun casee (z as {rules, ...}) =
         if Vector.isEmpty rules
            then Error.bug "CoreML.Exp.casee"
         else make (Case z, ty (#exp (Vector.first rules)))

      fun iff (test, thenCase, elseCase): t =
         casee {ctxt = fn () => Layout.empty,
                kind = ("if", "branch"),
                nest = [],
                matchDiags = {nonexhaustiveExn = Control.Elaborate.DiagDI.Default,
                              nonexhaustive = Control.Elaborate.DiagEIW.Ignore,
                              redundant = Control.Elaborate.DiagEIW.Ignore},
                noMatch = Impossible,
                region = Region.bogus,
                rules = Vector.new2 ({exp = thenCase,
                                      layPat = NONE,
                                      pat = Pat.truee,
                                      regionPat = Region.bogus},
                                     {exp = elseCase,
                                      layPat = NONE,
                                      pat = Pat.falsee,
                                      regionPat = Region.bogus}),
                test = test}

      fun andAlso (e1, e2) = iff (e1, e2, falsee)

      fun orElse (e1, e2) = iff (e1, truee, e2)

      fun whilee {expr, test} =
         let
            val loop = Var.newNoname ()
            val loopTy = Type.arrow (Type.unit, Type.unit)
            val call = make (App (var (loop, loopTy), unit), Type.unit)
            val lambda =
               Lambda.make
               {arg = Var.newNoname (),
                argType = Type.unit,
                body = iff (test,
                            make (Seq (Vector.new2 (expr, call)),
                                  Type.unit),
                            unit),
                mayInline = true}
         in
            make
            (Let (Vector.new1 (Fun {decs = Vector.new1 {lambda = lambda,
                                                        var = loop},
                                    tyvars = fn () => Vector.new0 ()}),
                  call),
             Type.unit)
         end

      fun foreachVar (e: t, f: Var.t -> unit): unit =
         let
            fun loop (e: t): unit =
               case node e of
                  App (e1, e2) => (loop e1; loop e2)
                | Case {rules, test, ...} =>
                     (loop test
                      ; Vector.foreach (rules, loop o #exp))
                | Con _ => ()
                | Const _ => ()
                | EnterLeave (e, _) => loop e
                | Handle {handler, try, ...} => (loop handler; loop try)
                | Lambda l => loopLambda l
                | Let (ds, e) =>
                     (Vector.foreach (ds, loopDec)
                      ; loop e)
                | List es => Vector.foreach (es, loop)
                | PrimApp {args, ...} => Vector.foreach (args, loop)
                | Raise e => loop e
                | Record r => Record.foreach (r, loop)
                | Seq es => Vector.foreach (es, loop)
                | Var (x, _) => f (x ())
                | Vector es => Vector.foreach (es, loop)
            and loopDec d =
               case d of
                  Datatype _ => ()
                | Exception _ => ()
                | Fun {decs, ...} => Vector.foreach (decs, loopLambda o #lambda)
                | Val {rvbs, vbs, ...} =>
                     (Vector.foreach (rvbs, loopLambda o #lambda)
                      ; Vector.foreach (vbs, loop o #exp))
            and loopLambda (Lam {body, ...}) = loop body
         in
            loop e
         end
   end

structure Dec =
   struct
      datatype t = datatype dec

      fun dropProfile d =
         let
            fun loopExp e =
               let
                  fun mk node = Exp.make (node, Exp.ty e)
               in
                  case Exp.node e of
                     App (e1, e2) => mk (App (loopExp e1, loopExp e2))
                   | Case {ctxt, kind, nest, matchDiags, noMatch, region, rules, test} =>
                        mk (Case {ctxt = ctxt,
                                  kind = kind,
                                  nest = nest,
                                  matchDiags = matchDiags,
                                  noMatch = noMatch,
                                  region = region,
                                  rules = Vector.map (rules, fn {exp, layPat, pat, regionPat} =>
                                                      {exp = loopExp exp,
                                                       layPat = layPat,
                                                       pat = pat,
                                                       regionPat = regionPat}),
                                  test = loopExp test})
                   | Con _ => e
                   | Const _ => e
                   | EnterLeave (exp, _) => loopExp exp
                   | Handle {catch, handler, try} =>
                        mk (Handle {catch = catch,
                                    handler = loopExp handler,
                                    try = loopExp try})
                   | Lambda lambda => mk (Lambda (loopLambda lambda))
                   | Let (decs, exp) => mk (Let (Vector.map (decs, loopDec), loopExp exp))
                   | List exps => mk (List (Vector.map (exps, loopExp)))
                   | PrimApp {args, prim, targs} =>
                        mk (PrimApp {args = Vector.map (args, loopExp),
                                     prim = prim,
                                     targs = targs})
                   | Raise exp => mk (Raise (loopExp exp))
                   | Record r => mk (Record (Record.map (r, loopExp)))
                   | Seq exps => mk (Seq (Vector.map (exps, loopExp)))
                   | Var _ => e
                   | Vector exps => mk (Vector (Vector.map (exps, loopExp)))
               end
            and loopDec d =
               case d of
                  Datatype _ => d
                | Exception _ => d
                | Fun {decs, tyvars} =>
                     Fun {decs = Vector.map (decs, fn {lambda, var} =>
                                             {lambda = loopLambda lambda,
                                              var = var}),
                          tyvars = tyvars}
                | Val {matchDiags, rvbs, tyvars, vbs} =>
                     Val {matchDiags = matchDiags,
                          rvbs = Vector.map (rvbs, fn {lambda, var} =>
                                             {lambda = loopLambda lambda,
                                              var = var}),
                          tyvars = tyvars,
                          vbs = Vector.map (vbs, fn {ctxt, exp, layPat, nest, pat, regionPat} =>
                                            {ctxt = ctxt,
                                             exp = loopExp exp,
                                             layPat = layPat,
                                             nest = nest,
                                             pat = pat,
                                             regionPat = regionPat})}
            and loopLambda (Lam {arg, argType, body, mayInline}) =
               Lam {arg = arg, argType = argType, body = loopExp body, mayInline = mayInline}
         in
            loopDec d
         end
      val layout = layoutDec
   end

structure Program =
   struct
      datatype t = T of {decs: Dec.t vector}


      fun dropProfile (T {decs}) =
         (Control.profile := Control.ProfileNone
          ; T {decs = Vector.map (decs, Dec.dropProfile)})

      fun layouts (T {decs, ...}, output') =
         let
            open Layout
            (* Layout includes an output function, so we need to rebind output
             * to the one above.
             *)
            val output = output'
         in
            output (Layout.str "\n")
            ; Vector.foreach (decs, output o Dec.layout)
         end

      val toFile = {display = Control.Layouts layouts, style = Control.ML, suffix = "core-ml"}

      fun layoutStats (program as T {...}) =
         let
            open Layout
         in
            align
            [Control.sizeMessage ("coreML program", program)]
         end

(*       fun typeCheck (T {decs, ...}) =
 *       let
 *          fun checkExp (e: Exp.t): Ty.t =
 *             let
 *                val (n, t) = Exp.dest e
 *                val 
 *                datatype z = datatype Exp.t
 *                val t' =
 *                   case n of
 *                      App (e1, e2) =>
 *                         let
 *                            val t1 = checkExp e1
 *                            val t2 = checkExp e2
 *                         in
 *                            case Type.deArrowOpt t1 of
 *                               NONE => error "application of non-function"
 *                             | SOME (u1, u2) =>
 *                                  if Type.equals (u1, t2)
 *                                     then t2
 *                                  else error "function/argument mismatch"
 *                         end
 *                    | Case {rules, test} =>
 *                         let
 *                            val {pat, exp} = Vector.first rules
 *                         in
 *                            Vector.foreach (rules, fn {pat, exp} =>
 *                                            Type.equals
 *                                            (checkPat pat, 
 *                         end
 *             in
 *                                   
 *             end
 *       in
 *       end
 *)
   end

end
