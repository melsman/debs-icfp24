datatype bop = ADD | MUL | SUB | DIV
datatype e = Var of string | Num of real | Tup of e list
           | Sel of int * e | Bin of bop * e * e

val pr_bop = fn ADD => "+" | MUL => "*" | SUB => "-" | DIV => "/"

val rec pr =
 fn Var x => x
  | Num r => Real.toString r
  | Tup es => "[" ^ String.concatWith "," (map pr es) ^ "]"
  | Sel (i,e) => "#" ^ Int.toString i ^ "(" ^ pr e ^ ")"
  | Bin (b,e1,e2) => "(" ^ pr e1 ^ pr_bop b ^ pr e2 ^ ")"

val ex : e = Sel (0, Tup [Bin (MUL, Num 2.0, Var "pi"), Num 1.0])

val () = print (pr ex ^ "\n")
