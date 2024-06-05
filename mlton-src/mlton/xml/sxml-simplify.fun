(* Copyright (C) 2019,2021 Matthew Fluet.
 * Copyright (C) 1999-2008 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

functor SxmlSimplify (S: SXML_SIMPLIFY_STRUCTS): SXML_SIMPLIFY = 
struct

open S

structure ImplementExceptions = ImplementExceptions (open S)
structure ImplementSuffix = ImplementSuffix (open S)
structure Polyvariance = Polyvariance (open S)
(* structure Uncurry = Uncurry (open S) *)
structure CPSTransform = CPSTransform (open S)

fun polyvariance (hofo, rounds, small, product) p =
   Ref.fluidLet
   (Control.polyvariance,
    SOME {hofo = hofo, rounds = rounds, small = small, product = product},
    fn () => Polyvariance.transform p)

type pass = {name: string,
             doit: Program.t -> Program.t,
             execute: bool}

val sxmlPassesDefault =
   {name = "sxmlShrink1", doit = S.shrink, execute = true} ::
   {name = "implementSuffix", doit = ImplementSuffix.transform, execute = true} ::
   {name = "sxmlShrink2", doit = S.shrink, execute = true} ::
   {name = "implementExceptions", doit = ImplementExceptions.transform, execute = true} ::
   {name = "sxmlShrink3", doit = S.shrink, execute = true} ::
   (* {name = "uncurry", doit = Uncurry.transform, execute = true} :: *)
   (* {name = "sxmlShrink4", doit = S.shrink, execute = true} :: *)
   {name = "polyvariance", doit = Polyvariance.transform, execute = true} ::
   {name = "sxmlShrink4", doit = S.shrink, execute = true} ::
   nil

val sxmlPassesCpsTransform =
   sxmlPassesDefault @
   {name = "cpsTransform", doit = CPSTransform.transform, execute = true} ::
   {name = "cpsSxmlShrink5", doit = S.shrink, execute = true} ::
   {name = "cpsPolyvariance", doit = Polyvariance.transform, execute = true} ::
   {name = "cpsSxmlShrink6", doit = S.shrink, execute = true} ::
   nil

val sxmlPassesMinimal =
   {name = "implementSuffix", doit = ImplementSuffix.transform, execute = true} ::
   {name = "implementExceptions", doit = ImplementExceptions.transform, execute = true} ::
   nil

val sxmlPasses : pass list ref = ref sxmlPassesDefault

local
   type passGen = string -> pass option

   fun mkSimplePassGen (name, doit): passGen =
      let val next = Counter.generator 1
      in fn s => if s = name
                    then SOME {name = name ^ "#" ^ 
                               (Int.toString (next ())),
                               doit = doit,
                               execute = true}
                    else NONE
      end

   val polyvariancePassGen =
      let
         val next = Counter.generator 1
         fun nums s =
            if s = ""
               then SOME []
            else if String.sub (s, 0) = #"(" 
                    andalso String.sub (s, String.size s - 1)= #")"
               then let
                       val s = String.dropFirst (String.dropLast s)
                    in
                       case List.fold (String.split (s, #","), SOME [],
                                       fn (s,SOME nums) => (case Int.fromString s of
                                                               SOME i => SOME (i::nums)
                                                             | NONE => NONE)
                                        | (_, NONE) => NONE) of
                          SOME (l as _::_) => SOME (List.rev l)
                        | _ => NONE
                    end
            else NONE
      in
         fn s =>
         if String.hasPrefix (s, {prefix = "polyvariance"})
            then let
                    fun mk (hofo, rounds, small, product) =
                       SOME {name = concat ["polyvariance(", 
                                            Bool.toString hofo, ",",
                                            Int.toString rounds, ",",
                                            Int.toString small, ",",
                                            Int.toString product, ")#",
                                            Int.toString (next ())],
                             doit = polyvariance (hofo, rounds, small, product),
                             execute = true}
                    val s = String.dropPrefix (s, String.size "polyvariance")
                 in
                    case nums s of
                       SOME [] => mk (true, 2, 30, 300)
                     | SOME [hofo, rounds, small, product] =>
                          mk (hofo <> 0, rounds, small, product)
                     | _ => NONE
                 end
         else NONE
      end

   val passGens =
      polyvariancePassGen ::
      (List.map([("sxmlShrink", S.shrink),
                 ("implementExceptions", ImplementExceptions.transform),
                 ("implementSuffix", ImplementSuffix.transform)],
                mkSimplePassGen))
in
   fun sxmlPassesSetCustom s =
      Exn.withEscape
      (fn esc =>
       (let val ss = String.split (s, #":")
        in
           sxmlPasses :=
           List.map(ss, fn s =>
                    case (List.peekMap (passGens, fn gen => gen s)) of
                       NONE => esc (Result.No s)
                     | SOME pass => pass)
           ; Result.Yes ()
        end))
end

fun sxmlPassesSet s =
   case s of
      "default" => (sxmlPasses := sxmlPassesDefault
                    ; Result.Yes ())
    | "cpsTransform" => (sxmlPasses := sxmlPassesCpsTransform
                         ; Result.Yes ())
    | "minimal" => (sxmlPasses := sxmlPassesMinimal
                    ; Result.Yes ())
    | _ => sxmlPassesSetCustom s
val _ = Control.OptimizationPasses.register {il = "sxml", set = sxmlPassesSet}

fun simplify p =
   let
      val sxmlPasses = !sxmlPasses
      val p =
         Control.simplifyPasses
         {arg = p,
          passes = sxmlPasses,
          stats = Program.layoutStats,
          toFile = Program.toFile,
          typeCheck = typeCheck}
   in
      p
   end
end
