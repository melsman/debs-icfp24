(*TypeInfo is part of the ElabInfo.  See ELAB_INFO for an
 overview of the different kinds of info.*)

signature TYPE_INFO =
  sig
    type TyName = TyName.TyName

    type longid
    type Type
    type TyVar
    type TyEnv
    type Env
    type realisation
    type opaq_env
    type strid 
    eqtype tycon 
    type id
    type Basis

    (*
     * Note that we record tyvars and types (and not typeschemes as 
     * one could imagine); this is not accidentally: we don't 
     * want to risk that the bound type variables are renamed (by alpha-conversion) ---
     * the compiler is a bit picky on the exact type information, so alpha-conversion
     * is not allowed on recorded type information!
     *)

    datatype TypeInfo =
	LAB_INFO of {index: int}
			(* Attached to PATROW. Gives the alphabetic
			   index (0..n-1) for the record label. 
			 *)

      | RECORD_ATPAT_INFO of {Type : Type}
	                (* Attachec to RECORDatpat during elaboration,
			   The type (which is a record type) is used when 
			   overloading is resolved
			   to insert the correct indeces in LAB_INFO of patrows.
			 *)

      | VAR_INFO of {instances : Type list}
	                (* Attached to IDENTatexp,
			   instances is the list of types which have been 
			   chosen to instantiate the generic tyvars at this 
			   variable.
			 *)
      | VAR_PAT_INFO of {tyvars: TyVar list, Type: Type}
	                (* Attached to LAYEREDpat and LONGIDatpat (for LONGVARs)
			   The Type field is the type of the pattern corresponding
			   to the variable, tyvars are the bound type variables;
			   there will only be bound tyvars when attached to a pattern
			   in a valbind. *)
      | CON_INFO of {numCons: int, index: int, instances: Type list,longid:longid}
			(* Attached to IDENTatexp, LONGIDatpat, CONSpat.
			   numCons is the number of constructors for this type.
			   instances is the list of types wich have been
			   chosen to instantiate the generic tyars at this 
			   occurrence of the constructor.
			 *)
      | EXCON_INFO of {Type: Type,longid:longid}
			(* Attached to IDENTatexp, LONGIDatpat, CONSpat.
			   The Type field is the type of the occurrence of the
			   excon. *)
      | EXBIND_INFO of {TypeOpt: Type option}
	                (* Attached to EXBIND
			 * None if nullary exception constructor *)
      | TYENV_INFO of TyEnv
	                (* Attached to DATATYPEdec, TYPEdec and DATATYPE_REPLICATIONdec
			 * The type environment associated with the declaration *)
      | ABSTYPE_INFO of TyEnv * realisation
	                (* Attached to ABSTYPEdec
			 * The type environment associated with the declaration and
			 * a realisation to get from the abstract type names to the
			 * type names of the datbind associated with the abstype 
			 * construct *)
      | EXP_INFO of {Type: Type} 
	                (* Attached to all exp's and SCONatexp *)
      | MATCH_INFO of {Type: Type}
	                (* Attached to MATCH and SCONatpat *)
      | PLAINvalbind_INFO of {tyvars: TyVar list, Type: Type}
	                (* Attached to PLAINvalbind 
			   for 'pat = exp' this is the type of the exp, and 
			   a list of bound type variables. *)
      | OPEN_INFO of strid list * tycon list * id list
	                (* Attached to OPENdec; the lists contains those
			 * identifiers being declared by the dec. *)
      | INCLUDE_INFO of strid list * tycon list
	                (* Attached to INCLUDEspec; the lists contains those
			 * strids and tycons being specified by the spec. *)
      | FUNCTOR_APP_INFO of {rea_inst : realisation, rea_gen : realisation, Env : Env}
                        (* Attached to functor applications; The env is the
			 * elaboration result of the functor application; the 
			 * rea_inst realisation instantiates formal type names with 
			 * actual types and the rea_gen realisation maps generative 
			 * names of the functor into fresh names. *)
      | FUNBIND_INFO of {argE: Env, elabBref: Basis ref, T: TyName.Set.Set, resE: Env, opaq_env_opt: opaq_env option}
                        (* Attached to functor bindings; argE is the
			 * environment resulting from elaborating the
			 * sigexp in a functor binding; elabBref is the
			 * basis for elaborating the functor body; a reference
			 * is used to allow for restricting the basis to
			 * the free identifiers of the functor body during the
			 * FreeIds phase; T is the set of type names generated 
			 * during elaboration of the functor body; resE is
			 * the environment resulting from elaborating
			 * the functor body; rea_opt is used for
			 * opacity elimination. Part of the info is
			 * there to make it possible to re-build an
			 * elaborated functor body structure
			 * expression from the source. *)
      | TRANS_CONSTRAINT_INFO of Env
	                (* Attached to transparent signature constraints *)
      | OPAQUE_CONSTRAINT_INFO of Env * realisation
	                (* Attached to opaque signature constraints *)

      | SIGBIND_INFO of TyName.Set.Set    (* Attached to signature bindings; those 
					   * type names that occur free in the 
					   * elaborated signature. *)

      | DELAYED_REALISATION of realisation * TypeInfo   (* To support delayed realisation of
							 * type info. *)

    val on_TypeInfo : realisation * TypeInfo -> TypeInfo  (* delayed realisation *)
    val normalise : TypeInfo -> TypeInfo                  (* force realisations *)

    type StringTree
    val layout : TypeInfo -> StringTree
  end;
