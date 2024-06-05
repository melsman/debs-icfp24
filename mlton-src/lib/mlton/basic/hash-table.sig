(* Copyright (C) 2018-2019 Jason Carr, Matthew Fluet.
 * Copyright (C) 2009 Matthew Fluet.
 * Copyright (C) 1999-2006 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)
signature HASH_TABLE =
   sig
      type ('a, 'b) t

      val fold: ('a, 'b) t * 'c * ('b * 'c -> 'c) -> 'c
      val foldi: ('a, 'b) t * 'c * ('a * 'b * 'c -> 'c) -> 'c
      val foreach: ('a, 'b) t * ('b -> unit) -> unit
      val foreachi: ('a, 'b) t * ('a * 'b -> unit) -> unit
      val insertIfNew: ('a, 'b) t * 'a * (unit -> 'b) * ('b -> unit) -> 'b
      val layout: ('a * 'b -> Layout.t) -> ('a, 'b) t -> Layout.t
      val lookupOrInsert: ('a, 'b) t * 'a * (unit -> 'b) -> 'b
      val new: {equals: 'a * 'a -> bool,
                hash: 'a -> word} -> ('a, 'b) t
      val peek: ('a, 'b) t * 'a -> 'b option
      val remove: ('a, 'b) t * 'a -> unit
      val removeAll : ('a, 'b) t * ('a * 'b -> bool) -> unit
      val removeWhen: ('a, 'b) t * 'a * ('b -> bool) -> unit
      val size: ('a, 'b) t -> int
      val stats': ('a, 'b) t -> Layout.t
      val toList: ('a, 'b) t -> ('a * 'b) list
   end
