(** Monomorphic sets.

The MONO_SET signature is a generic interface to monomorphic sets.
*)

signature MONO_SET = sig
  type set
  type elem

  val empty      : set
  val singleton  : elem -> set
  val size       : set -> int
  val isEmpty    : set -> bool
  val member     : elem * set -> bool
  val eq         : set * set -> bool
  val list       : set -> elem list
  val fromList   : elem list -> set
  val insert     : elem * set -> set
  val remove     : elem * set -> set
  val difference : set * set -> set
  val intersect  : set * set -> set
  val union      : set * set -> set
  val partition  : (elem -> bool) -> set -> set * set
  val fold       : (elem * 'b -> 'b) -> 'b -> set -> 'b
  val app        : (elem -> unit) -> set -> unit
end

(**

[type set] The set type.

[type elem] The type of elements.

[empty] The empty set.

[singleton e] The singleton set {e}.

[size s] The cardinality of the set s.

[isEmpty s] returns true if the set is empty. Returns false otherwise.

[member (e, s)] returns true if e is in s Returns false otherwise.

[eq (s1, s2)] returns true if the two sets s1 and s2 are
equal. Returns false otherwise.

[list s] returns the elements of s as a list. The order is
implementation dependent.

[fromList l] returns the set consisting of the elements in the list l.

[insert (e, s)] returns s with e inserted.

[remove (e, s)] returns s with e removed.

[difference (s1, s2)] returns s1 with the elements in s2 removed.

[intersect (s1, s2)] returns the intersection of s1 and s2.

[union (s1, s2)] returns the union of s1 and s2.

[partition f s] returns a pair of sets (s1, s2) where f returns true
for each element in s1 and false for each element in s2 and where s is
the union of s1 and s2. The order in which f is applied to the
elements of s is implementation dependent.

[fold f base s] folds using f over the base element. The order in
which f is applied to the elements of s is implementation dependent.

[app f s] applies f to each element of s (the order is implementation
dependent).

*)
