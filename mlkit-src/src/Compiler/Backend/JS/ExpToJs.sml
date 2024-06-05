structure ExpToJs : EXP_TO_JS =
struct

fun die s = (print (s ^"\n");raise Fail s)

structure L = LambdaExp

type LambdaPgm = L.LambdaPgm
type Exp = L.LambdaExp

datatype conRep =
         BOOL of bool                      
       | ENUM of int
       | STD of int
       | UNBOXED_NULL
       | UNBOXED_UNARY

structure Env = struct
 structure M = Con.Map
 type t = conRep M.map
 val empty : t = M.empty
 val initial : t = 
     let open TyName
     in M.fromList [
        (Con.con_FALSE, BOOL false),
        (Con.con_TRUE, BOOL true),
        (Con.con_NIL, UNBOXED_NULL),
        (Con.con_CONS, UNBOXED_UNARY),
        (Con.con_QUOTE, STD 0),
        (Con.con_ANTIQUOTE, STD 1),
        (Con.con_REF, STD 0),
        (Con.con_INTINF, STD 0)
        ]
     end
 val plus : t * t -> t = M.plus
 fun restrict (e,l) : t = M.restrict (Con.pr_con,e,l)
 val enrich : t * t -> bool = M.enrich (op =)

 val pu_conRep = 
     Pickle.dataGen 
         ("conRep",
          fn BOOL b => 0
           | ENUM i => 1
           | STD i => 2
           | UNBOXED_NULL => 3
           | UNBOXED_UNARY => 4,
          [fn _ => Pickle.con1 BOOL (fn BOOL b => b | _ => die "pu_conRep.BOOL") Pickle.bool,
           fn _ => Pickle.con1 ENUM (fn ENUM i => i | _ => die "pu_conRep.ENUM") Pickle.int,
           fn _ => Pickle.con1 STD (fn STD i => i | _ => die "pu_conRep.STD") Pickle.int,
           Pickle.con0 UNBOXED_NULL,
           Pickle.con0 UNBOXED_UNARY])

 val pu = M.pu Con.pu pu_conRep

 fun fromDatbinds (L.DATBINDS dbss) : t =
     let
       fun flatten (es:t list) : t =
           List.foldl plus empty es
       val all_nullary = 
           List.all (fn (_,NONE) => true | _ => false)
       fun onAll C cs = 
           #1(List.foldl(fn ((c,_),(e,i)) => (M.add(c,C i,e),i+1)) (M.empty,0) cs)
       fun unboxable [(c0,NONE),(c1,SOME _)] = SOME(c1,c0)
         | unboxable [(c1,SOME _),(c0,NONE)] = SOME(c1,c0)
         | unboxable _ = NONE
       fun fromDb (tvs,t,cs) = 
             if TyName.unboxed t then
               if all_nullary cs then
                 onAll ENUM cs
               else
                 case unboxable cs of
                   SOME (c_unary,c_nullary) =>
                   M.fromList [(c_unary,UNBOXED_UNARY),(c_nullary,UNBOXED_NULL)]
                 | NONE => onAll STD cs
             else  onAll STD cs
     in flatten(map (flatten o map fromDb) dbss)
     end
end

datatype Js = $ of string | & of Js * Js | V of (string * Js) list * Js | Par of Js | StToE of Js | returnJs of Js | IfJs of Js * Js * Js

infix & &&

val emp = $""

(* 
Mutually recursive functions are compiled into properties of a
common object:
 
    var x = {};
    x.f = function(...){... x.g(...) ...};
    x.g = function(...){... x.f(...) ...};
    f = x.f;
    g = x.g;

Here x is a fresh variable. To map f and g to x.f and x.g, we make use
of a map (:lvar->lvar) in the context.
*) 
structure Context :> sig type t
                       val mk : Env.t -> t
                       val empty : t
                       val add : t -> Lvars.lvar * string -> t
                       val lookup : t -> Lvars.lvar -> string option
                       val envOf : t -> Env.t
                     end =
struct
  type t = Env.t * string Lvars.Map.map
  fun mk e = (e,Lvars.Map.empty)
  val empty = (Env.empty, Lvars.Map.empty)
  fun add (e,c) (lv,s) = (e,Lvars.Map.add(lv,s,c))
  fun envOf (e,c) = e            
  fun lookup (e,c) lv = Lvars.Map.lookup c lv
end

local
  type lvar = Lvars.lvar
  type excon = Excon.excon
  val frameLvars : lvar list ref = ref nil
  val frameExcons : excon list ref = ref nil

  (* function to replace first occurence of a sub-string in a string *)
  fun replaceString (s0:string,s1:string) (s:string) : string =
      let val ss = Substring.full s
          val (ss1,ss2) = Substring.position s0 ss
      in if Substring.size ss2 > 0 (* there was a match *) then
           let val ss3 = Substring.triml (size s0) ss2
           in Substring.concat[ss1,Substring.full s1,ss3]
           end
         else s (* no match *)
      end

  fun normalizeBase b = 
      let val b = replaceString (".mlb-", "$") b
          val b = replaceString (".sml1", "$") b
      in
        String.translate (fn #"." => "$" | c => Char.toString c) b
      end

  val localBase : string option ref = ref NONE

  fun maybeUpdateLocalBase n : bool (* Singleton(true) *) =
      true before
      (case !localBase of 
         SOME _ => ()  (* no need to set it again! *)
       | NONE => localBase := SOME((normalizeBase o #2 o Name.key) n))

  fun isFrameLvar lvar () =
      List.exists (fn lv => Lvars.eq(lv,lvar)) (!frameLvars)
      andalso maybeUpdateLocalBase (Lvars.name lvar)

  fun isFrameExcon excon () =
      List.exists (fn e => Excon.eq(e,excon)) (!frameExcons)
      andalso maybeUpdateLocalBase (Excon.name excon)

  val symbolChars = "!%&$#+-/:<=>?@\\~`^|*"
                    
  fun isSymbol s = 
      Char.contains symbolChars (String.sub(s,0))
      handle _ => die "isSymbol.empty"

  fun idfy_c (c:char) : string =
      case CharVector.findi (fn(_,e) => e = c) symbolChars
       of SOME(i,_) => Char.toString(Char.chr(97+i))
        | NONE => Char.toString c

  fun idfy s =
      if isSymbol s then
        "s$" ^ String.translate idfy_c s
      else String.translate (fn #"'" => "$"             (* Notice: the patching *)
                              | #"." => "$"             (* below  makes the ids *)
                              | c => Char.toString c) s (* unique... *)

  (* convert identifier names such as "v343" and "var322" into "v" - the name key
   * is appended later, which will make the identifiers unique... *)

  val idfy = 
      let
        fun restDigits i s = 
            CharVectorSlice.all Char.isDigit (CharVectorSlice.slice(s,i,NONE))
        fun simplify s =
              (if String.sub(s,0) = #"v" then
                 if restDigits 1 s then "v"
                 else
                   if String.sub(s,1) = #"a" 
                      andalso String.sub(s,2) = #"r" 
                      andalso restDigits 3 s then "v"
                   else s
               else s) handle _ => s
      in fn s => simplify(idfy s)
      end

  fun patch n f s opt =
      case opt of
        NONE =>
        let val (k,b) = Name.key n
            val s = s ^ "$" ^ Int.toString k
        in if Name.rigid n orelse f() then
             let val b = normalizeBase b
             in b ^ "." ^ s
             end
           else s
        end
      | SOME s0 => s0 ^ ".$" ^ s
in
  fun setFrameLvars xs = frameLvars := xs
  fun setFrameExcons xs = frameExcons := xs
  fun resetBase() = localBase := NONE

  fun pr_lv lv = idfy(Lvars.pr_lvar lv)

  fun prLvar C lv =
      patch (Lvars.name lv) 
            (isFrameLvar lv) 
            (pr_lv lv)
            (Context.lookup C lv)   (* Fix variables *)
  fun prLvarExport lv =
      patch (Lvars.name lv) (fn() => true) (pr_lv lv) NONE
  fun exconName e = 
      patch (Excon.name e) (isFrameExcon e) ("en$" ^ idfy(Excon.pr_excon e)) NONE
  fun exconExn e = 
      patch (Excon.name e) (isFrameExcon e) ("exn$" ^ idfy(Excon.pr_excon e)) NONE
  fun exconExnExport e = 
      patch (Excon.name e) (fn() => true) ("exn$" ^ idfy(Excon.pr_excon e)) NONE
  fun getLocalBase() = !localBase
  fun fresh_fixvar() =
      prLvar Context.empty (Lvars.new_named_lvar "fix")
end

fun toJSString s =
    let 
      fun digit n = chr(48 + n);
      fun toJSescape (c:char) : string =
	case c of
	    #"\\"   => "\\\\"
	  | #"\""   => "\\\""
	  | _       =>
	    if #"\032" <= c andalso c <= #"\126" then str c
	    else
		(case c of
		     #"\010" => "\\n"			(* LF,  10 *)
		   | #"\013" => "\\r"			(* CR,  13 *)
		   | #"\009" => "\\t"			(* HT,   9 *)
		   | #"\011" => "\\v"			(* VT,  11 *)
		   | #"\008" => "\\b"			(* BS,   8 *)
		   | #"\012" => "\\f"			(* FF,  12 *)
                   | _       => let val n = ord c
				in implode[#"\\", digit(n div 64), digit(n div 8 mod 8),
					   digit(n mod 8)]
				end)          
          
    in "\"" ^ String.translate toJSescape s ^ "\""
    end

fun j1 && j2 =
    j1 & $" " & j2

fun mlToJsReal s =
    String.translate (fn #"~" => "-" | c => Char.toString c) s

fun mlToJsInt v =
    String.translate (fn #"~" => "-" | c => Char.toString c) (Int32.toString v)

fun sToS0 s : Js = $(toJSString s)

fun sToS s : Js = 
    $"new String(" & sToS0 s & $")"

(*
fun cToS0 c : Js = 
    $("\"" ^ String.toString (Con.pr_con c) ^ "\"")
*)

fun unPar (e:Js) = 
    case e of
      Par e => e
    | _ => e

fun parJs (e: Js) : Js = 
    case e of
      Par _ => e
    | _ => Par e

fun sqparJs (e:Js) : Js =
    $"[" & unPar e & $"]"

local
  fun loop xs =
      case xs
       of nil => $""
        | [x] => unPar x
        | x::xs => unPar x & $", " & loop xs 
in
fun seq (jss : Js list) : Js =
    $"(" & loop jss & $")"
fun array (jss : Js list) : Js =
    $"[" & loop jss & $"]"
end

fun appi f es = 
  let fun loop (n,nil) = nil
        | loop (n,x::xs) = f(n,x) :: loop(n+1,xs)
  in loop (0, es)
  end

fun stToE (st : Js) : Js = StToE st

val unitValueJs = "0"

local 
  fun pp_int i =
      $(mlToJsInt (Int32.fromInt i))
in
  fun ppCon C c : Js =
      case Env.M.lookup (Context.envOf C) c of
        SOME(STD i) => pp_int i
      | SOME(ENUM i) => pp_int i
      | SOME(BOOL true) => $"true" 
      | SOME(BOOL false) => $"false" 
      | SOME UNBOXED_NULL => $"null"
      | _ => die "ppCon" 
  fun ppConNullary C c : Js =
    case Env.M.lookup (Context.envOf C) c of
      SOME(STD i) => array[pp_int i]
    | SOME(ENUM i) => pp_int i
    | SOME(BOOL true) => $"true" 
    | SOME(BOOL false) => $"false" 
    | SOME UNBOXED_NULL => $"null"
    | SOME UNBOXED_UNARY => die "ppConNullary: UNBOXED_UNARY applied to argument" 
    | NONE => die ("ppConNullary: constructor " ^ Con.pr_con c ^ " not in context")
  fun ppConUnary C c e : Js =
    case Env.M.lookup (Context.envOf C) c of
      SOME(STD i) => array[pp_int i,e]
    | SOME(ENUM i) => die "ppConUnary: ENUM"
    | SOME(BOOL _) => die "ppConUnary: BOOL"
    | SOME UNBOXED_NULL => die "ppConUnary: UNBOXED_NULL"
    | SOME UNBOXED_UNARY => e
    | NONE => die ("ppConUnary: constructor " ^ Con.pr_con c ^ " not in context")
end

(* 

Arithmetic int32 operations check explicitly for overflow and throw
the Overflow exception in this case. Arithmetic word32 operations
truncate the result to make it fit into 32 bits.

int31 values are represented as int32 values (msb of the 32 bits is
the sign-bit); thus, int32 comparisons can be used for int31
comparisons. Moreover, int31 operations (+,-,*,/) can be implemented using
int32 operations, as long as we check for overflow after the operation
(is the result in the desired int31 interval?)

word31 values are represented as 31 bits, which means that bit
operations (&, |) may be implemented using word32 operations, but
arithmentic operations must consider signs explicitly. *)
 
fun wrapWord31 (js: Js) : Js =
    parJs(js & $" & 0x7FFFFFFF")

fun wrapWord32 (js: Js) : Js =
    parJs(js & $" & 0xFFFFFFFF")

fun callPrim0 n =
    $n & seq[]

fun callPrim1 n e =
    $n & seq[e]

fun callPrim2 n e1 e2 =
    $n & seq[e1,e2]

fun chkOvfI32 (e: Js) : Js =
    callPrim1 "SmlPrims.chk_ovf_i32" e

fun chkOvfI31 (e: Js) : Js =
    callPrim1 "SmlPrims.chk_ovf_i31" e

fun pToJs2 name e1 e2 =
 case name of
      "__plus_int32ub" => chkOvfI32(e1 & $"+" & e2)
    | "__plus_int31" => chkOvfI31(e1 & $"+" & e2)
    | "__plus_word32ub" => wrapWord32(e1 & $"+" & e2)
    | "__plus_word31" => wrapWord31(e1 & $"+" & e2)
    | "__plus_real" => parJs(e1 & $"+" & e2)
    | "__minus_int32ub" => chkOvfI32(e1 & $"-" & e2)
    | "__minus_int31" => chkOvfI31(e1 & $"-" & e2)
    | "__minus_word32ub" => wrapWord32(e1 & $"-" & e2)
    | "__minus_word31" => wrapWord31(e1 & $"-" & e2)
    | "__minus_real" => parJs(e1 & $"-" & e2)
    | "__mul_int32ub" => chkOvfI32(e1 & $"*" & e2)
    | "__mul_int31" => chkOvfI31(e1 & $"*" & e2)
    | "__mul_word32ub" => wrapWord32(e1 & $"*" & e2)
    | "__mul_word31" => wrapWord31(e1 & $"*" & e2)
    | "__mul_real" => parJs(e1 & $"*" & e2)

    | "__less_int32ub" => parJs(e1 & $"<" & e2)
    | "__lesseq_int32ub" => parJs(e1 & $"<=" & e2)
    | "__greatereq_int32ub" => parJs(e1 & $">=" & e2)
    | "__greater_int32ub" => parJs(e1 & $">" & e2)
    | "__equal_int32ub" => parJs(e1 & $" == " & e2)
    | "__less_int31" => parJs(e1 & $"<" & e2)
    | "__lesseq_int31" => parJs(e1 & $"<=" & e2)
    | "__greatereq_int31" => parJs(e1 & $">=" & e2)
    | "__greater_int31" => parJs(e1 & $">" & e2)
    | "__equal_int31" => parJs(e1 & $" == " & e2)
    | "__less_word32ub" => parJs(e1 & $"<" & e2)
    | "__lesseq_word32ub" => parJs(e1 & $"<=" & e2)
    | "__greatereq_word32ub" => parJs(e1 & $">=" & e2)
    | "__greater_word32ub" => parJs(e1 & $">" & e2)
    | "__equal_word32ub" => parJs(e1 & $" == " & e2)
    | "__less_word31" => parJs(e1 & $"<" & e2)
    | "__lesseq_word31" => parJs(e1 & $"<=" & e2)
    | "__greatereq_word31" => parJs(e1 & $">=" & e2)
    | "__greater_word31" => parJs(e1 & $">" & e2)
    | "__equal_word31" => parJs(e1 & $" == " & e2)

    | "__less_real" => parJs(e1 & $"<" & e2)
    | "__lesseq_real" => parJs(e1 & $"<=" & e2)
    | "__greatereq_real" => parJs(e1 & $">=" & e2)
    | "__greater_real" => parJs(e1 & $">" & e2)
    | "__bytetable_sub" => parJs e1 & $".charCodeAt" & parJs e2
    | "concatStringML" => parJs(e1 & $"+" & e2)
    | "word_sub0" => parJs e1 & sqparJs e2
    | "word_table_init" => $"SmlPrims.wordTableInit" & seq[e1,e2]
    | "greatereqStringML" => parJs(e1 & $">=" & e2)
    | "greaterStringML" => parJs(e1 & $">" & e2)
    | "lesseqStringML" => parJs(e1 & $"<=" & e2)
    | "lessStringML" => parJs(e1 & $"<" & e2)

    | "__shift_right_unsigned_word32ub" => parJs(e1 & $" >>> " & e2)
    | "__shift_right_unsigned_word31" => parJs(e1 & $" >>> " & e2)
    | "__shift_right_signed_word32ub" => parJs(e1 & $" >> " & e2)
    | "__shift_right_signed_word31" => 
      IfJs(e1 & $" & -0x40000000", 
           parJs(parJs(e1 & $" | 0x80000000") & $" >> " & e2) & $" & 0x7FFFFFFF", 
           e1 & $" >> " & e2)

    | "__shift_left_word31" => wrapWord31(e1 & $" << " & parJs(e2 & $" & 0x1F"))
    | "__shift_left_word32ub" => wrapWord32(e1 & $" << " & parJs(e2 & $" & 0x1F"))

    | "__andb_word32ub" => parJs(e1 & $"&" & e2)
    | "__andb_word31" => parJs(e1 & $"&" & e2)
    | "__andb_word" => parJs(e1 & $"&" & e2)

    | "__orb_word32ub" => parJs(e1 & $"|" & e2)
    | "__orb_word31" => parJs(e1 & $"|" & e2)
    | "__orb_word" => parJs(e1 & $"|" & e2)

    | "__xorb_word32ub" => parJs(e1 & $"^" & e2)
    | "__xorb_word31" => parJs(e1 & $"^" & e2)
    | "__xorb_word" => parJs(e1 & $"^" & e2)
                       
    | "__quot_int31" => chkOvfI31(callPrim2 "SmlPrims.quot" e1 e2)
    | "__rem_int31" => parJs(e1 & $"%" & e2)
    | "__quot_int32ub" => chkOvfI32(callPrim2 "SmlPrims.quot" e1 e2)
    | "__rem_int32ub" => parJs(e1 & $"%" & e2)

    | "divFloat" => parJs(e1 & $"/" & e2)
    | "remFloat" => parJs(e1 & $"%" & e2)
    | "atan2Float" => $"Math.atan2" & seq[e1,e2]

    | "powFloat" => $"Math.pow" & seq[e1,e2]

    | "stringOfFloatFix" => parJs e2 & $".toFixed" & parJs e1
    | "stringOfFloatSci" => parJs e2 & $".toExponential" & parJs e1
    | "stringOfFloatGen" => parJs e2 & $".toPrecision" & parJs e1

    | _ => die ("pToJs2.unimplemented: " ^ name)

fun pToJs3 name e1 e2 e3 =
    case name 
     of "word_update0" => seq[parJs e1 & sqparJs e2 & $" = " & e3, 
                              $unitValueJs]
      | "__mod_int32ub" => $"SmlPrims.mod_i32" & seq[e1,e2,e3]
      | "__mod_int31" => $"SmlPrims.mod_i31" & seq[e1,e2,e3]
      | "__mod_word32ub" => $"SmlPrims.mod_w32" & seq[e1,e2,e3]
      | "__mod_word31" => $"SmlPrims.mod_w31" & seq[e1,e2,e3]
      | "__div_int32ub" => $"SmlPrims.div_i32" & seq[e1,e2,e3]
      | "__div_int31" => $"SmlPrims.div_i31" & seq[e1,e2,e3]
      | "__div_word32ub" => $"SmlPrims.div_w32" & seq[e1,e2,e3]
      | "__div_word31" => $"SmlPrims.div_w31" & seq[e1,e2,e3]

      | _ => die ("pToJs3.unimplemented: " ^ name)

fun pToJs1 name e =
    case name
     of "__bytetable_size" => parJs e & $".length"
      | "implodeCharsML" => callPrim1 "SmlPrims.implode" e
      | "implodeStringML" => callPrim1 "SmlPrims.concat" e
      | "charsToCharArray" => callPrim1 "SmlPrims.charsToCharArray" e
      | "charArraysConcat" => callPrim1 "SmlPrims.charArraysConcat" e
      | "printStringML" => callPrim1 "document.write" e
      | "exnNameML" => parJs e & $"[0]"
      | "id" => e
      | "word_table0" => $"Array" & parJs e
      | "table_size" => parJs e & $".length"
      | "chararray_to_string" => callPrim1 "SmlPrims.charArrayToString" e

      | "__neg_int32ub" => chkOvfI32($"-" & e)
      | "__neg_int31" => chkOvfI31($"-" & e)
      | "__neg_real" => parJs ($"-" & e)
      | "__abs_int32ub" => chkOvfI32(callPrim1 "Math.abs" e)
      | "__abs_int31" => chkOvfI31(callPrim1 "Math.abs" e)
      | "__abs_real" => callPrim1 "Math.abs" e

      | "__int32ub_to_int" => e
      | "__int_to_int32ub" => e
      | "__int31_to_int32ub" => e
      | "__int31_to_int" => e
      | "__word_to_word32ub" => e
      | "__word_to_word32ub_X" => e
      | "__word31_to_word32ub" => e
      | "__word31_to_word" => e
      | "__word32ub_to_word" => e

      | "__int32ub_to_int31" => chkOvfI31 e
      | "__int_to_int31" => chkOvfI31 e

      | "__word32ub_to_int" => chkOvfI32 e
      | "__word32ub_to_int32ub" => chkOvfI32 e
      | "__word32_to_int_X_JS" => callPrim1 "SmlPrims.w32_to_i32_X" e
      | "__word31_to_int_X_JS" => callPrim1 "SmlPrims.w31_to_i32_X" e
      | "__word32_to_int32_X_JS" => callPrim1 "SmlPrims.w32_to_i32_X" e
      | "__word31_to_word32ub_X" => callPrim1 "SmlPrims.w31_to_w32_X" e
      | "__word31_to_word_X" => callPrim1 "SmlPrims.w31_to_w32_X" e
      | "__int32_to_word32_JS" => callPrim1 "SmlPrims.i32_to_w32" e
      | "__int_to_word32" => callPrim1 "SmlPrims.i32_to_w32" e
      | "__int_to_word31_JS" => callPrim1 "SmlPrims.i32_to_w31" e
      | "__word32ub_to_word31" => wrapWord31 e
      | "__word_to_word31" => wrapWord31 e

      | "isnanFloat" => callPrim1 "isNaN" e
      | "sqrtFloat" => callPrim1 "Math.sqrt" e
      | "sinFloat" => callPrim1 "Math.sin" e
      | "cosFloat" => callPrim1 "Math.cos" e
      | "asinFloat" => callPrim1 "Math.asin" e
      | "acosFloat" => callPrim1 "Math.acos" e
      | "atanFloat" => callPrim1 "Math.atan" e
      | "sinhFloat" => callPrim1 "SmlPrims.sinh" e
      | "coshFloat" => callPrim1 "SmlPrims.cosh" e
      | "tanhFloat" => callPrim1 "SmlPrims.tanh" e
      | "lnFloat" => callPrim1 "Math.log" e
      | "expFloat" => callPrim1 "Math.exp" e

      | "realInt" => e

      | "floorFloat" => chkOvfI32(callPrim1 "Math.floor" e)
      | "ceilFloat" => chkOvfI32(callPrim1 "Math.ceil" e)
      | "truncFloat" => chkOvfI32(callPrim1 "SmlPrims.trunc" e)
      | "sml_localtime" => callPrim1 "SmlPrims.localtime" e
      | "sml_gmtime" => callPrim1 "SmlPrims.gmtime" e
      | "sml_mktime" => callPrim1 "SmlPrims.mktime" e
      | _ => die ("pToJs1 unimplemented: " ^ name)

fun pToJs0 name =
    case name
     of "posInfFloat" => $"Infinity"
      | "negInfFloat" => parJs($"-Infinity")
      | "sml_getrealtime" => callPrim0 "SmlPrims.getrealtime"
      | "sml_localoffset" => callPrim0 "SmlPrims.localoffset"
      | _ => die ("pToJs0 unimplemented: " ^ name)

fun pToJs name [] = pToJs0 name
  | pToJs name [e] = pToJs1 name e
  | pToJs name [e1,e2] = pToJs2 name e1 e2
  | pToJs name [e1,e2,e3] = pToJs3 name e1 e2 e3
  | pToJs name _ = die ("pToJs unimplemented: " ^ name)

fun varJs (v:string) (js1:Js) (js2:Js) =
    case js2 of
      V(B,js3) => V((v,js1)::B,js3)
    | _ => V([(v,js1)],js2)
      
fun toJsSw (toJs: Exp->Js) (pp:'a->string) (L.SWITCH(e:Exp,bs:('a*Exp)list,eo: Exp option)) =
    let  val default = 
             case eo 
              of SOME e => $"default: " & returnJs (toJs e)
               | NONE => emp
         val cases = foldr(fn ((a,e),acc) => $"case" && $(pp a) && $": " & returnJs(toJs e) && acc) default bs 

    in
      stToE($"switch(" & unPar (toJs e) & $") { " & cases & $" }")
    end

fun booleanBranch bs eo =
    case eo of
      SOME e => 
      (case bs of
         [((c,_),e')] => 
         (if Con.eq(c, Con.con_FALSE) then SOME(e,e')
          else (if Con.eq(c, Con.con_TRUE) then SOME(e',e)
                else NONE))
       | _ => NONE)
    | NONE => 
      (case bs of
         [((c1,_),e1),((c2,_),e2)] => 
         (if Con.eq(c1, Con.con_TRUE) then SOME(e1,e2)
          else (if Con.eq(c1, Con.con_FALSE) then SOME(e2,e1)
                else NONE))
       | _ => NONE)

fun unboxedBranch C bs eo =
    case eo of
      SOME e' =>
      (case bs of
         [((c,_),e)] =>
         (case Env.M.lookup (Context.envOf C) c of
            SOME UNBOXED_NULL => SOME(e,e')
          | SOME UNBOXED_UNARY => SOME(e',e)
          | _ => NONE)
       | _ => NONE)
    | NONE => 
      (case bs of
         [((c,_),e1),(_,e2)] =>
         (case Env.M.lookup (Context.envOf C) c of
            SOME UNBOXED_NULL => SOME(e1,e2)
          | SOME UNBOXED_UNARY => SOME(e2,e1)
          | _ => NONE)
       | _ => NONE)

fun enumeration C (((c,_),_)::_) =
    (case Env.M.lookup (Context.envOf C) c of
       SOME(ENUM _) => true
     | _ => false)
  | enumeration _ _ = false

fun toJsSw_C C (toJs: Exp->Js) (L.SWITCH(e:Exp,bs:((Con.con*Lvars.lvar option)*Exp)list,eo: Exp option)) =
    case booleanBranch bs eo of 
      SOME(e1,e2) => IfJs (toJs e,toJs e1,toJs e2)
    | NONE =>
      case unboxedBranch C bs eo of 
        SOME(e1,e2) => IfJs (parJs(toJs e) & $" == null",toJs e1,toJs e2)
      | NONE => 
        let
          fun pp (c,lvopt) = ppCon C c
          fun gen unboxed =
              let val e_js = if unboxed then toJs e
                             else parJs(toJs e) & $"[0]"
                  val default = 
                      case eo of 
                        SOME e => $"default: " & returnJs(toJs e)
                      | NONE => emp
                  val cases = foldr(fn ((a,e),acc) => $"case" && pp a && $": " & returnJs(parJs(toJs e)) && acc) default bs                     
              in stToE($"switch(" & e_js & $") { " & cases & $" }")
              end
        in if enumeration C bs then gen true
           else gen false
        end

fun toJsSw_E (toJs: Exp->Js) (L.SWITCH(e:Exp,bs:((Excon.excon*Lvars.lvar option)*Exp)list,eo: Exp option)) =
    let 
      val cases =
          List.foldr (fn (((excon,_),e),acc) =>
                         $"if (tmp[0] == " & $(exconName excon) & $") { " & returnJs(toJs e) & $" };\n" & acc) emp bs
      val default = 
          case eo 
           of SOME e => returnJs(toJs e)
            | NONE => die "toJsSw_E.no default"
    in
      stToE($"var tmp = " & unPar(toJs e) & $";\n" & cases & default)
    end

fun lvarInExp lv e =
    let exception FOUND
        fun f (L.VAR{lvar,...}) =
            if Lvars.eq(lv,lvar) then raise FOUND
            else ()
          | f e = LambdaBasics.app_lamb f e
    in (f e; false) 
       handle FOUND => true
    end

fun monoNonRec [{lvar,bind=L.FN{pat,body,...},tyvars=_,Type=_}] =
    if lvarInExp lvar body then NONE
    else SOME(lvar,pat,body)
  | monoNonRec _ = NONE

fun toJs (C:Context.t) (e0:Exp) : Js = 
  case e0 of 
    L.VAR {lvar,...} => $(prLvar C lvar)
  | L.INTEGER (value,_) => if value < 0 then parJs($(mlToJsInt value)) else $(mlToJsInt value)
  | L.WORD (value,_) => $(Word32.fmt StringCvt.DEC value)
  | L.STRING s => sToS0 s
  | L.REAL s => if String.sub(s,0) = #"~" then parJs($(mlToJsReal s)) else $(mlToJsReal s)
  | L.PRIM(L.CONprim {con,...},nil) => ppConNullary C con
  | L.PRIM(L.CONprim {con,...},[e]) => ppConUnary C con (toJs C e)
  | L.PRIM(L.DECONprim {con,...}, [e]) => 
    (case Env.M.lookup (Context.envOf C) con of
       SOME(STD _) => seq [toJs C e] & $"[1]"
     | SOME UNBOXED_UNARY => toJs C e
     | SOME _ => die ("toJs.PRIM(DECON): constructor " ^ Con.pr_con con ^ " associated with NULLARY constructor info")
     | NONE => die ("toJs.PRIM(DECON): constructor " ^ Con.pr_con con ^ " not in context"))
  | L.PRIM(L.EXCONprim excon,nil) => (* nullary *)
    $(exconExn excon)
  | L.PRIM(L.EXCONprim excon,[e]) => (* unary *)
    array[$(exconName excon), toJs C e]

  | L.PRIM(L.DEEXCONprim excon,[e]) => (* unary *)
    parJs (toJs C e) & $"[1]"

  | L.PRIM(L.RECORDprim, []) => $unitValueJs
  | L.PRIM(L.RECORDprim, es) => array(map (toJs C) es)
  | L.PRIM(L.UB_RECORDprim, [e]) => toJs C e
  | L.PRIM(L.UB_RECORDprim, es) => die ("UB_RECORD unimplemented. size(args) = " 
                                        ^ Int.toString (List.length es))
  | L.PRIM(L.SELECTprim i,[e]) => seq [toJs C e] & $("[" ^ Int.toString i ^ "]")

  | L.PRIM(L.DEREFprim _, [e]) => parJs (toJs C e) & $"[0]"
  | L.PRIM(L.REFprim _, [e]) => (*seq[$"tmp = Array(1)", $"tmp[0] = " & toJs C e, $"tmp"]*)
    array[toJs C e]
  | L.PRIM(L.ASSIGNprim _, [e1,e2]) => seq[parJs (toJs C e1) & $"[0] = " & toJs C e2,
                                           $unitValueJs]
  | L.PRIM(L.DROPprim, [e]) => toJs C e
  | L.PRIM(L.DROPprim, _) => die "DROPprim unimplemented"
                                  
  | L.PRIM(L.EQUALprim _, [e1,e2]) => parJs (toJs C e1 & $"==" & toJs C e2)
                                    
  | L.FN {pat,body} => 
    let val lvs = map ($ o prLvar C o #1) pat
    in $"function" & seq lvs & $"{ " & returnJs(toJs C body) & $" }"
    end
  | L.LET {pat=[p],bind,scope} => 
    let val lv = #1 p
    in varJs (prLvar C lv) 
             (unPar(toJs C bind))
             (toJs C scope)
    end
  | L.LET {pat=[],bind,scope} => (* memo: why not sequence? *)
    varJs ("__dummy") 
          (unPar(toJs C bind))
          (toJs C scope)
  | L.LET {pat,bind,scope} => 
    let val lvs = map #1 pat
        val binds = case bind of L.PRIM(UB_RECORDprim,binds) => binds
                               | _ => die "LET.unimplemented"
        fun loop (nil,nil) = (toJs C scope)
          | loop (lv::lvs,b::bs) =
            varJs (prLvar C lv) 
                  (unPar(toJs C b))
                  (loop(lvs,bs))
          | loop _ = die "LET.mismatch"
    in 
      loop(lvs,binds)
    end
  | L.FIX{functions,scope} => 
    let val scopeJs = toJs C scope
    in case monoNonRec functions of
         SOME (lv,pat,body) =>
         let val lvs = map ($ o prLvar C o #1) pat
         in varJs (prLvar C lv) 
                  ($"function " & seq lvs & $"{ " & returnJs(toJs C body) & $" }")
                  scopeJs
         end
       | NONE =>
         let 
           val fixvar = fresh_fixvar()
           fun pr_fix_lv lv = fixvar ^ ".$" ^ pr_lv lv   (* needs to be consistent with patch above *)
           val C' = foldl(fn(lvar,C) => Context.add C (lvar,fixvar)) C (map #lvar functions)
           val js2 = foldl(fn(lv,js) => varJs (prLvar C lv) ($(pr_fix_lv lv)) js) scopeJs (map #lvar functions)
           val js = foldl(fn ({lvar=f_lv,bind=L.FN{pat,body},...},acc) =>
                           let val lvs = map ($ o prLvar C o #1) pat
                           in varJs (pr_fix_lv f_lv) 
                                    ($"function " & seq lvs & $"{ " & returnJs(toJs C' body) & $" }")
                                    acc
                           end
                           | _ => die "toJs.malformed FIX") js2 functions
         in varJs fixvar ($"{}") js
         end
    end
  | L.APP(e1,L.PRIM(L.UB_RECORDprim, es),_) => toJs C e1 & seq(map (toJs C) es)
  | L.APP(e1,e2,_) => toJs C e1 & seq[toJs C e2]
                    
  | L.SWITCH_I {switch,precision} => toJsSw (toJs C) mlToJsInt switch
  | L.SWITCH_W {switch,precision} => toJsSw (toJs C) (Word32.fmt StringCvt.DEC) switch
  | L.SWITCH_S switch => toJsSw (toJs C) toJSString switch
  | L.SWITCH_C switch => toJsSw_C C (toJs C) switch
  | L.SWITCH_E switch => toJsSw_E (toJs C) switch

  (* In EXPORTprim below, we could eta-convert e and add code to check
   * that the type of the argument is compatiple with instance_arg. *)
  | L.PRIM(L.EXPORTprim {name,instance_arg,instance_res},[e]) => 
    seq[$("SMLtoJs." ^ name ^ " = ") & toJs C e,
        $unitValueJs]
  | L.PRIM(L.EXPORTprim {name,instance_arg,instance_res}, _) => 
    die "toJs.PRIM(EXPORTprim) should take exactly one argument"

  | L.PRIM(L.CCALLprim {name,...},exps) => 
    (case name of
       "execStmtJS" =>
       (case exps 
         of L.STRING s :: L.STRING argNames :: args =>  (* static code *)
            ($("(function (" ^ argNames ^ ") { " ^ s ^ " })") & seq(map (toJs C) args))
          | s :: argNames :: args => (* dynamic code *)
            parJs(parJs($"new Function" & seq[toJs C argNames, toJs C s])
                       & seq(map (toJs C) args))
          | _ => die "toJs.execStmtJS : string-->string-->args")
     | "callJS" => 
       (case exps 
         of L.STRING f :: args =>  (* static code *)
            ($f & seq(map (toJs C) args))
          | f :: args => (* dynamic code *)
            let val xs = ((String.concatWith ",") o #2)
                         (foldl (fn (_,(i,acc)) => (i+1,"a" ^ Int.toString i::acc)) (0,nil) args)
            in
              parJs(parJs($"new Function" & seq[$("\"" ^ xs ^ "\""), $"\"return \" + " & toJs C f & $(" + \"(" ^ xs ^ ")\"")])
                         & seq(map (toJs C) args))
            end
          | _ => die "toJs.callJS : string-->args")
     | _ => pToJs name (map (toJs C) exps)
    )
  | L.PRIM _ => die "toJs.PRIM unimplemented"
  | L.FRAME {declared_lvars, declared_excons} => $unitValueJs
(*
    let val lvs = map #lvar declared_lvars
    in seq([$"frame = new Object()"] 
           @ map (fn lv => $"frame." & $(prLvar C lv) & $" = " & $(prLvar C lv)) lvs 
           @ [$"frame"])
    end
*)
  | L.HANDLE (e1,e2) => (* memo: avoid capture of variable e! *)
    let val lv = Lvars.newLvar()
        val v = prLvar C lv
    in stToE ($"try { " & returnJs(toJs C e1) & $" } catch(" & $v & $") { " & returnJs(parJs(toJs C e2) & parJs($v)) & $" }")
    end
  | L.EXCEPTION (excon,SOME _,scope) => (* unary *)
    let val s = Excon.pr_excon excon  (* for printing *)
    in varJs (exconName excon) (sToS s) (toJs C scope)
    end
  | L.EXCEPTION (excon,NONE,scope) => (* nullary; precompute exn value and store it in exconExn(excon)... *)
    let val s = Excon.pr_excon excon  (* for printing *)
      val exn_id = exconExn excon
    in varJs (exconName excon) (sToS s) 
             (varJs (exconExn excon) (array[$(exconName excon)])
                    (toJs C scope))
    end
  | L.RAISE(e,_) => stToE ($"throw" & parJs(toJs C e) & $";\n")

val toJs = fn (env0, L.PGM(dbss,e)) => 
              let 
                val (lvars,excons) = LambdaBasics.exports e
                val _ = setFrameLvars lvars
                val _ = setFrameExcons excons
                val _ = resetBase()
                val env' = Env.fromDatbinds dbss
                val env = Env.plus(env0,env')
                val js = toJs (Context.mk env) e
                val js = 
                    case getLocalBase() of
                      SOME b => $"if (typeof(" & $b & $") == 'undefined') { " & $b & $" = {}; }\n" & js
                    | NONE => js
              in (js, env')
              end

fun toString (js:Js) : string = 
    let
      fun elim js =
          case js of
            $ _ => js
          | j1 & j2 => elim j1 & elim j2
          | V (B,js_scope) => 
            let fun binds var = 
                    foldr(fn ((s,js),acc) => 
                             let val var = if CharVector.exists (fn #"." => true | _ => false) s then $"" else var
                             in var & $s && $"=" && elim js & $";\n" & acc
                             end) emp B
            in if js_scope = $"" then binds emp
               else stToE(binds ($"var ") & returnJs(elim js_scope))
            end
          | Par js => Par (elim js)
          | StToE js => StToE (elim js)
          | returnJs js => returnJs(elim js)
          | IfJs(e1,e2,e3) => IfJs(elim e1,elim e2,elim e3)
      fun strs b ($s,acc) = s::acc
        | strs b (js1&js2,acc) = strs b (js1,strs b (js2,acc))
        | strs b (Par js,acc) = "("::strs false (js,")"::acc)
        | strs b (returnJs js,acc) = 
          (case unPar js of
             StToE js => strs b (js,acc)
           | IfJs(e,e1,e2) => strs false ($"if " & seq[e] & $" { " & returnJs e1 & $" } else { " & returnJs e2 & $" };\n", acc)
           | js => strs false ($"return " & js & $";\n",acc))
        | strs b (IfJs(e,e1,e2),acc) = strs false (parJs(parJs e & $"?" & parJs e1 & $":" & parJs e2),acc)
        | strs b (StToE js,acc) = 
          if b then strs false ($"__dummy = function(){ " & js & $" }()",acc)
          else strs false ($"function(){ " & js & $" }()",acc)
        | strs _ _ = die "toString.strs"
    in String.concat(strs true (elim js,nil))
    end handle ? => (print "Error in toString\n"; raise ?)

fun toFile (f,js) : unit = 
    let val os = TextIO.openOut f
    in 
      ( TextIO.output(os,toString js) ; TextIO.closeOut os )
      handle ? => (TextIO.closeOut os; raise ?)
    end

fun pp_list ss = "[" ^ String.concatWith "," ss ^ "]"

fun exports (L.PGM(_,e)) =
    let val (ls,es) = LambdaBasics.exports e
        val ss = map prLvarExport ls @ map exconExnExport es 
(*        val _ = print ("Exports: " ^ pp_list ss ^ "\n") *)
    in ss
    end

fun imports (L.PGM(_,e)) =
    let val (ls,es) = LambdaBasics.freevars e
        val ss = map (prLvar Context.empty) ls @ map exconExn es 
(*        val _ = print ("Imports: " ^ pp_list ss ^ "\n") *)
    in ss
    end

end
