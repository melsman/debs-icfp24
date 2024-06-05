(* Copyright (C) 2014,2017,2019-2021 Matthew Fluet.
 * Copyright (C) 2004-2007 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

functor WordXVector (S: WORD_X_VECTOR_STRUCTS): WORD_X_VECTOR =
struct

open S

datatype t = T of {elementSize: WordSize.t,
                   elements: WordX.t vector}

local
   fun make f (T r) = f r
in
   val elementSize = make #elementSize
   val elements = make #elements
end

fun layout (T {elements, elementSize}) =
   let
      fun vector () =
         Layout.seq
         [Layout.str "#[",
          Layout.fill (Layout.separateRight
                       (Vector.toListMap
                        (elements, fn w =>
                         WordX.layout (w, {suffix = true})),
                        ",")),
          Layout.str "]",
          Layout.str (":w" ^ WordSize.toString elementSize ^ "v")]
      fun string cs =
         Layout.seq
         [Layout.str "\"",
          Layout.str (String.escapeSML (String.implodeV cs)),
          Layout.str "\""]
   in
      if WordSize.equals (elementSize, WordSize.word8)
         then let
                 val cs = Vector.map (elements, WordX.toChar)
                 val l = Vector.length cs
                 val n = Vector.fold (cs, 0, fn (c, n) =>
                                      if Char.isGraph c
                                         orelse Char.isSpace c
                                         then n + 1
                                         else n)
              in
                 if l = 0 orelse (10 * n) div l > 9
                    then string cs
                    else vector ()
              end
         else vector ()
   end

val toString = Layout.toString o layout

val parse =
   let
      open Parse
      infix  1 <|> >>=
      infix  3 *>
   in
      (spaces *> char Char.dquote *>
       many (fromScan Char.scan) >>= (fn cs =>
       char Char.dquote *>
       pure (T {elements = Vector.fromListMap (cs, WordX.fromChar),
                elementSize = WordSize.byte})))
      <|>
      (spaces *> str "#[" *>
       sepBy (WordX.parse, spaces *> str ",") >>= (fn ws =>
       spaces *> str "]" *>
       str ":w" *> WordSize.parse >>= (fn s =>
       str "v" *>
       pure (T {elements = Vector.fromList ws,
                elementSize = s}))))
   end

val hash = String.hash o toString

fun equals (v, v') =
   WordSize.equals (elementSize v, elementSize v')
   andalso Vector.equals (elements v, elements v', WordX.equals)

fun compare (v, v') =
   if WordSize.equals (elementSize v, elementSize v')
      then case Int.compare (Vector.length (elements v), Vector.length (elements v')) of
              LESS => LESS
            | EQUAL => Vector.compare (elements v, elements v', fn (w, w') =>
                                       WordX.compare (w, w', {signed = false}))
            | GREATER => GREATER
      else Error.bug "WordXVector.compare"

fun le (v, v') =
   case compare (v, v') of
      LESS => true
    | EQUAL => true
    | GREATER => false

fun foldFrom (v, start, b, f) = Vector.foldFrom (elements v, start, b, f)

fun forall (v, f) = Vector.forall (elements v, f)

fun foreach (v, f) = Vector.foreach (elements v, f)

fun fromVector ({elementSize}, v) =
   T {elementSize = elementSize,
      elements = v}

fun fromList ({elementSize}, l) =
   T {elementSize = elementSize,
      elements = Vector.fromList l}

fun fromListRev ({elementSize}, l) =
   T {elementSize = elementSize,
      elements = Vector.fromListRev l}

fun fromString s =
   T {elementSize = WordSize.byte,
      elements = Vector.tabulate (String.size s, fn i =>
                                  WordX.fromChar (String.sub (s, i)))}

fun length v = Vector.length (elements v)

fun sub (v, i) = Vector.sub (elements v, i)

fun tabulate ({elementSize}, n, f) =
   T {elementSize = elementSize,
      elements = Vector.tabulate (n, f)}

fun toListMap (v, f) = Vector.toListMap (elements v, f)

fun toVectorMap (v, f) = Vector.map (elements v, f)

end
