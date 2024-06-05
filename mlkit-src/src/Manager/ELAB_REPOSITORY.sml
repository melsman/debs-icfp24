
signature ELAB_REPOSITORY =
  sig

    structure TyName : TYNAME

    type funid and InfixBasis and ElabBasis and opaq_env and name and longstrid
    type absprjid

    val empty_infix_basis : InfixBasis
    val empty_opaq_env : opaq_env

    val clear : unit -> unit
    val delete_entries : absprjid * funid -> unit

	  (* Repository lookup's return the first entry for a (absprjid,funid)
	   * that is reusable (i.e. where all export (ty-)names are
	   * marked generative.) In particular, this means that an
	   * entry that has been added, cannot be returned by a
	   * lookup, prior to executing `recover().' The integer
	   * provided by the lookup functions can be given to the
	   * overwrite functions for owerwriting a particular
	   * entry. *)

    val lookup_elab : (absprjid * funid) -> 
      (int * (InfixBasis * ElabBasis * longstrid list * (opaq_env * TyName.Set.Set) * name list * 
	      InfixBasis * ElabBasis * opaq_env)) option

    val add_elab : (absprjid * funid) * 
      (InfixBasis * ElabBasis * longstrid list * (opaq_env * TyName.Set.Set) * name list * 
       InfixBasis * ElabBasis * opaq_env) -> unit

    val owr_elab : (absprjid * funid) * int * 
      (InfixBasis * ElabBasis * longstrid list * (opaq_env * TyName.Set.Set) * name list * 
       InfixBasis * ElabBasis * opaq_env) -> unit

    val recover : unit -> unit

          (* Before building a project the repository should be
	   * ``recovered''. The recovering phase takes care of 
	   * marking all export names as generative (see NAME). Then,
	   * when an entry is reused, export names are marked non-
	   * generative (for an entry to be reused all export names 
	   * must be marked generative.) *)

    type elabRep
    val getElabRep : unit -> elabRep
    val setElabRep : elabRep -> unit
    val pu_dom : (absprjid * funid) Pickle.pu
    val pu : elabRep Pickle.pu
  end