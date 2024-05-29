(* calc.sml *)

(* This file provides glue code for building the calculator using the
 * parser and lexer specified in calc.lex and calc.grm.
*)

structure Calc : sig val parse : unit -> unit
                     val parseString : string -> int option
                 end =
struct

(*
 * We apply the functors generated from calc.lex and calc.grm to produce
 * the CalcParser structure.
 *)

  structure CalcLrVals =
    CalcLrValsFun(structure Token = LrParser.Token)

  structure CalcLex =
    CalcLexFun(structure Tokens = CalcLrVals.Tokens)

  structure CalcParser =
    Join(structure LrParser = LrParser
	 structure ParserData = CalcLrVals.ParserData
	 structure Lex = CalcLex)

(*
 * We need a function which given a lexer invokes the parser. The
 * function invoke does this.
 *)

  fun invoke lexstream =
      let fun print_error (s,i:int,_) =
	      TextIO.output(TextIO.stdOut,
			    "Error, line " ^ (Int.toString i) ^ ", " ^ s ^ "\n")
       in CalcParser.parse(0,lexstream,print_error,())
      end

(*
 * Finally, we need a driver function that reads one or more expressions
 * from the standard input. The function parse, shown below, does
 * this. It runs the calculator on the standard input and terminates when
 * an end-of-file is encountered.
 *)

  fun parse0 g =
      let val lexer = CalcParser.makeLexer g
	  val dummyEOF = CalcLrVals.Tokens.EOF(0,0)
	  val dummySEMI = CalcLrVals.Tokens.SEMI(0,0)
	  fun loop lexer =
	      let val (result,lexer) = invoke lexer
		  val (nextToken,lexer) = CalcParser.Stream.get lexer
		  val _ = case result
			    of SOME r =>
				TextIO.output(TextIO.stdOut,
				       "result = " ^ (Int.toString r) ^ "\n")
			     | NONE => ()
	       in if CalcParser.sameToken(nextToken,dummyEOF) then ()
		  else loop lexer
	      end
       in loop lexer
      end

  fun parse () =
      parse0 (fn _ => case TextIO.inputLine TextIO.stdIn of
                          SOME x => x | NONE => raise Fail "parse")

  fun parseString (s:string) : int option =
      let val lexer = CalcParser.makeLexer (fn _ => s)
	  val (result,_) = invoke lexer
      in result
      end

end (* structure Calc *)
