(** Basic Javascript and DOM operations.

Basic operations for accessing the DOM tree and basic JavaScript
functionality.
*)

signature JS =
  sig
    (* dom *)
    eqtype win
    eqtype doc
    eqtype elem
    val window          : win
    val openWindow      : string -> string -> string -> win
    val closeWindow     : win -> unit
    val windowDocument  : win -> doc
    val document        : doc
    val documentElement : doc -> elem
    val documentWrite   : doc -> string -> unit
    val getElementById  : doc -> string -> elem option
    val parent          : elem -> elem option
    val firstChild      : elem -> elem option
    val lastChild       : elem -> elem option
    val nextSibling     : elem -> elem option
    val previousSibling : elem -> elem option
    val innerHTML       : elem -> string -> unit
    val value           : elem -> string
    val setAttribute    : elem -> string -> string -> unit
    val removeAttribute : elem -> string -> unit
    val createElement   : string -> elem
    val createTextNode  : string -> elem
    val createFragment  : unit -> elem
    val appendChild     : elem -> elem -> unit
    val removeChild     : elem -> elem -> unit
    val replaceChild    : elem -> elem -> elem -> unit

    type ns (* name space *)
    val nsFromString    : string -> ns
    val createElementNS : ns -> string -> elem
    val setAttributeNS  : ns -> elem -> string -> string -> unit

    (* events *)
    datatype eventType = onclick | onchange | onkeypress
                       | onkeyup | onmouseover | onmouseout
    val installEventHandler : elem -> eventType -> (unit -> bool) -> unit
    val getEventHandler     : elem -> eventType -> (unit -> bool) option
    val onMouseMove         : doc -> (int*int -> unit) -> unit
    val onMouseMoveElem     : elem -> (int*int -> unit) -> unit

    (* timers *)
    type intervalId
    val setInterval     : int -> (unit -> unit) -> intervalId
    val clearInterval   : intervalId -> unit

    type timeoutId
    val setTimeout      : int -> (unit -> unit) -> timeoutId
    val clearTimeout    : timeoutId -> unit

    (* Cookies *)
    val setCookie       : doc -> string -> unit
    val getCookie       : doc -> string

    (* styles *)
    val setStyle        : elem -> string * string -> unit

    (* Position *)
    val xElem           : elem -> int
    val yElem           : elem -> int

    structure XMLHttpRequest : sig
      type req
      val new              : unit -> req
      val openn            : req -> {method: string, url: string, async: bool} -> unit
      val setRequestHeader : req -> string * string -> unit
      val setResponseType  : req -> string -> unit
      val send             : req -> string option -> unit
      val sendBinary       : req -> string -> unit
      val state            : req -> int        (* 0,1,2,3,4 *)
      val status           : req -> int option (* 200, 404, ... *)
      val onStateChange    : req -> (unit -> unit) -> unit
      val response         : req -> string option
      val responseArrBuf   : req -> string option
      val abort            : req -> unit
    end

    val random             : unit -> real

    val loadScript         : string -> (unit -> unit) -> unit

    (* Shorthand notation for creating elements *)
    structure Element : sig
      val $     : string -> elem
      val &     : elem * elem -> elem
      val taga0 : string -> (string*string)list -> elem
      val tag0  : string -> elem
      val tag   : string -> elem -> elem
      val taga  : string -> (string*string)list -> elem -> elem

      val nstaga0 : ns -> string -> (string*string)list -> elem
      val nstag0  : ns -> string -> elem
      val nstag   : ns -> string -> elem -> elem
      val nstaga  : ns -> string -> (string*string)list -> elem -> elem

      val toForeignPtr   : elem -> foreignptr
      val fromForeignPtr : foreignptr -> elem
    end
  end

(**

[parent e] returns SOME p, if p is the parent of e. Returns NONE if e
has no parent.

[appendChild e child] appends child to e.

[removeChild e child] removes child from e.

[replaceChild e new old] replaces old child from e with new child.

[random()] returns a random real in the interval [0.0,1.0[.

[loadScript url callback] loads the JavaScript file specified by the
url and execute the callback function once the script is fully
loaded. The loadScript function assumes that a head element is present
in the DOM.

*)
