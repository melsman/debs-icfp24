
structure CompilerEnvDummy: COMPILER_ENV =
  struct
    structure PP = PrettyPrint

    fun die s = Crash.impossible ("CompilerEnv."^s)

    val debug_man_enrich = Flags.lookup_flag_entry "debug_man_enrich"

    type con = unit
    type excon = unit
    type Type = unit
    type tyvar = unit
    type lvar = unit
    type id = Ident.id
    type longid = Ident.longid
    type strid = StrId.strid
    type longstrid = StrId.longstrid
    type tycon = TyCon.tycon
    type longtycon = TyCon.longtycon
    type TyName = TyName.TyName
    type cpath = int list

    datatype result = LVAR of lvar * tyvar list * Type * Type list
                    | CON of con * tyvar list * Type * Type list
                    | REF       (* ref is *not* a constructor in the backend, but a primitive! *)
                    | EXCON of excon * Type
                    | ABS | NEG | PLUS | MINUS | MUL | DIV | MOD | LESS 
		    | GREATER | LESSEQ | GREATEREQ
		                (* ABS .. GREATEREQ are place-holders for 
				   the built-in overloaded operators 
				   The compiler must turn these into the
				   corresponding PRIM_APP(n, ...) in
				   the lambda language *)
                    | RESET_REGIONS | FORCE_RESET_REGIONS
                    | PRIM	(* `PRIM' is a place-holder for the built-in
				   prim function: int * 'a -> 'b. The compiler
				   must turn this, plus its constant argument,
				   into a PRIM_APP(n, ...) in the lambda
				   language. *)

		    | EXPORT    (* Support for exporting ML functions to be used in
				 * C programs. The function _export has type 
				 * \/'a,'b. string * ('a -> 'b) -> unit. In a call 
				 * _export("myFun",fn a:int => a+1)
				 * the string "myFun" is the name of the assembled 
				 * function (following C calling conventions), and the
				 * function (fn a:int => a+1) is the ML function 
				 * called when the C function "myFun" is called from C 
				 * code. *)

    type CEnv = unit

    val emptyCEnv      = ()
    fun initialCEnv _ = ()

    type spath = int list
    fun declarePath _ = ()
    fun lookupPath _ _ = NONE
    fun clearPathEnv _ = ()
    fun declareVar(id, (lv, tyvars, tau), ()) = ()

    fun declareCon(id, (con,tyvars,tau), ()) = ()

    fun declareExcon(id, excon, ()) = ()

    fun declare_strid(strid, env, ()) = ()

    fun declare_tycon(tycon, a, ()) = ()

    fun plus ((), ()) = ()

    fun lookupId () id = REF

    fun lookup_strid () s = ()

    fun lookup_longid CEnv longid = NONE

    fun lookup_longstrid ce longstrid = ()

    fun lookup_tycon () tycon = die "lookup_tycon"

    fun lookup_longtycon ce longtycon = die "lookup_longtycon"

    fun lvars_result _ = nil

    fun primlvars_result (result, lvs) = nil

    fun cons_result _ = nil

    fun excons_result _ = nil

    fun tynames_tau _ = nil
    and tynames_taus _ = nil

    fun tynames_result _ = nil

    fun varsOfCEnv (vars_result : result * 'a list -> 'a list) ce : 'a list = nil

    val lvarsOfCEnv = fn _ => nil
    val consOfCEnv =  fn _ => nil
    val exconsOfCEnv =  fn _ => nil
    val primlvarsOfCEnv =  fn _ => nil 

    fun tynamesOfCEnv ce : TyName list = nil

    val restrictCEnv = fn _ => ()
     

    val enrichCEnv =  fn _ => true
       

    val match = fn _ => ()

   type TypeScheme = Environments.TypeScheme
   type ElabEnv = Environments.Env

   fun set_compileTypeScheme _ = ()

   fun constrain _ = ()

   type StringTree = PP.StringTree

   fun layoutCEnv () = PP.LEAF ""

   val pu = Pickle.unit
  end;

