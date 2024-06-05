signature WEB_CACHE = sig
  (* Cache kinds *)
  datatype kind =
     WhileUsed of Time.time option * int option
   | TimeOut of Time.time option * int option

  (* Cache Type *)
  type ('a,'b) cache
  include WEB_SERIALIZE
  type name = string

  (* Get or create a cache *)
  val get : 'a Type * 'b Type * name * kind -> ('a,'b) cache

  (* Entries in a cache *)
  val lookup : ('a,'b) cache -> 'a -> 'b option
  val insert : ('a,'b) cache * 'a * 'b * Time.time option -> bool
  val flush  : ('a,'b) cache -> unit
				
  (* Memoization *)
  val memoize  : ('a,'b) cache -> ('a -> 'b) -> 'a -> 'b
  val memoizeTime  : ('a,'b) cache ->
                     ('a -> ('b * Time.time option))
                     -> 'a -> 'b
  val memoizePartial : ('a,'b) cache ->
                       ('a -> 'b option) -> 'a -> 'b option
  val memoizePartialTime  : ('a,'b) cache ->
                            ('a -> ('b * Time.time option) option) ->
                            'a -> 'b option
  (* Cache info *)
  val pp_type  : 'a Type -> string
  val pp_cache : ('a,'b) cache -> string
end

(* 
 [kind] abstract type for cache kind. A cache kind describes
 the strategy used by the cache to insert and emit cache
 entries. The following strategies are supported:

   * WhileUsed (t,sz) : elements are emitted from the cache after
     approximately t time after the last use. The cache has a
     maximum size of sz bytes. Elements are emitted as needed in
     order to store new elements.  The size sz should not be too
     small, a minimum size of 1 Kb seems to work fine for small
     caches; larger cache sizes are also supported.

   * TimeOut (t,sz) : elements are emitted from the cache after
     approximately t time after they are inserted.

 [('a,'b) cache] abstract type of cache. A cache is a
 mapping from keys of type 'a to elements of type 'b. Only
 values of type 'a Type and 'b Type can be used as keys and
 elements, respectively.

 ['a Type] abstract type of either a key or element that
 can be used in a cache.

 [name] abstract type of the name of a cache.

 [get (cn,ck,aType,bType)] returns a cache which is named
 cn.  The cache will be a mapping from keys of type aType
 into elements of type bType. The cache strategy is
 described by ck.

  * If no cache exists with name cn, then a new cache is
    created.

  * If a cache c exists with name cn, then there are two
    possibilities:

     1) If c is a mapping from aType to bType, then c is
        returned.
          
     2) If c is not a mapping from aType to bType, then a
        new cache c' is created and returned.

    It is possible to create two caches with the same name,
    but only if they describe mappings of different type.

 [lookup c k] returns the value associated with the key k
 in cache c; returns NONE if k is not in the cache.

 [insert (c,k,v)] associates a key k with a value v in the cache c;
 overwrites existing entry in cache if k is present, in which case the
 function returns false. If no previous entry for the key is present
 in the cache, the function returns true.

 [flush c] deletes all entries in cache c.

 [memoize c f] implements memoization on the function f. The function
 f must be a mapping of keys and elements that can be stored in a
 cache, that is, f is of type 'a Type -> 'b Type.

 [memoizePartial c f] memoizes function values y where f returned SOME
 y.

 [pp_type aType] pretty prints the type aType.

 [pp_cache c] pretty prints the cache.
*)
