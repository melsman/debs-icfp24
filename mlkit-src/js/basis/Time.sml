(* Time -- new basis 1995-02-25, 1995-05-12 *)

structure Time : TIME =
  struct
    fun getrealtime() : {sec : int, usec : int} =
      prim("sml_getrealtime", ())

    (* Translation to obtain a longer time horizon.  Must agree with
       TIMEBASE used in sml_getrealtime. *)

    val timebase : int = ~2147483648 

    type time = {sec : int, usec : int}
    (* Invariant: sec >= timebase and 0 <= usec < 1000000.
       Represents the duration (sec-timebase)+usec/1000000 seconds; 
       or the duration since UTC 00:00 on 1 Jan 1970).
     *)

    exception Time

    val zeroTime = {sec = timebase, usec = 0};
    fun now () = getrealtime ();

    fun negpow10 p = Math.exp(Math.ln 10.0 * real (~p));

    fun fromSeconds s = 
	if IntInf.<(s, 0) then raise Time else {sec=LargeInt.toInt s + timebase, usec=0};

    fun fromMilliseconds ms = 
	if IntInf.<(ms, 0) then raise Time else 
	    {sec=LargeInt.toInt ms div 1000+timebase, usec=LargeInt.toInt ms mod 1000 * 1000}

    fun fromMicroseconds us = 
	if IntInf.<(us, 0) then raise Time else 
	    {sec=LargeInt.toInt us div 1000000+timebase, usec=LargeInt.toInt us mod 1000000}

    fun toSeconds {sec, usec} = 
	IntInf.-(LargeInt.fromInt sec, LargeInt.fromInt timebase)

    fun toMilliseconds {sec, usec} = 
	IntInf.+(IntInf.*(IntInf.-(LargeInt.fromInt sec, LargeInt.fromInt timebase), 1000), 
		 IntInf.div(LargeInt.fromInt usec, 1000))

    fun toMicroseconds {sec, usec} = 
	IntInf.+(IntInf.*(IntInf.-(LargeInt.fromInt sec, LargeInt.fromInt timebase), 1000000),
		 LargeInt.fromInt usec)

    fun fromReal r =		       
	let 
	    val rf = if r < 0.0 then raise Time else floor (r + real timebase)
	in
	    {sec = rf, usec = floor (1000000.0 * (r+real timebase-real rf))} 
	end handle Overflow => raise Time;

    fun toReal {sec, usec} =
	real sec - real timebase + real usec / 1000000.0;

    fun timeToUnits (t, p) = floor(toReal t * negpow10 p + 0.5);

    fun fmt p t =
	Real.fmt (StringCvt.FIX (SOME (if p > 0 then p else 0))) (toReal t)

(* Y2004 bug-fix
    fun fmt p {sec, usec} =
	let fun frac r = r - real (floor r) 
	    val rnd  = if p < 0 then 0.5 
		       else 0.5 * negpow10 p 
	    val usecr = real usec / 1000000.0 + rnd
	    val ints = Int.toString (sec - timebase + floor usecr)
	    fun h v i = if i <= 0 then []
			else Char.chr (floor v + Char.ord #"0") 
                             :: h (10.0 * frac v) (i-1)
	in 
	    if p > 0 then 
		ints ^ "." ^ String.implode (h (10.0 * frac usecr) 
					     (if p > 6 then 6 else p))
	    else ints
	end;
*)
    fun toString t = fmt 3 t;

    fun scan getc source =
    let fun skipWSget getc source = 
	    getc (StringCvt.dropl Char.isSpace getc source)
	fun decval c = Char.ord c - 48;
        fun pow10 0 = 1
	  | pow10 n = 10 * pow10 (n-1)
	fun mktime intgv decs fracv =
	    let val usecs = (pow10 (7-decs) * fracv + 5) div 10
	    in
		{sec = floor(intgv+real timebase+0.5) + usecs div 1000000, 
		 usec = usecs mod 1000000}
	    end
	fun skipdigs src =
	    case getc src of 
		NONE          => src
	      | SOME(c, rest) => if Char.isDigit c then skipdigs rest 
				 else src
	fun frac intgv decs fracv src =
	    if decs >= 7 then SOME(mktime intgv decs fracv, skipdigs src)
	    else case getc src of
		NONE          => SOME(mktime intgv decs fracv, src)
	      | SOME(c, rest) => 
		    if Char.isDigit c then 
			frac intgv (decs+1) (10 * fracv + decval c) rest
		    else 
			SOME(mktime intgv decs fracv, src)
	fun intg intgv src = 
	    case getc src of
		NONE              => SOME(mktime intgv 6 0, src)
	      | SOME (#".", rest) => frac intgv 0 0 rest
	      | SOME (c, rest)    => 
		    if Char.isDigit c then 
			intg (10.0 * intgv + real(decval c)) rest 
		    else SOME(mktime intgv 6 0, src)
    in case skipWSget getc source of
	NONE             => NONE
      | SOME(#".", rest) => 
		    (case getc rest of
			 NONE          => NONE
		       | SOME(c, rest) => 
			     if Char.isDigit c then frac 0.0 1 (decval c) rest
			     else NONE)
      | SOME(c, rest)    => 
	    if Char.isDigit c then intg (real (decval c)) rest else NONE
    end;

    fun fromString s = StringCvt.scanString scan s;

    val op + = fn ({sec=sec1, usec=usec1} : time, {sec=sec2, usec=usec2}) =>
	let val usecs = usec1 + usec2 in
	    {sec  = trunc(real sec1 - real timebase 
			  + real sec2 + real(usecs div 1000000)),
	     usec = usecs mod 1000000}
	end 
(*Y2004 bug-fix; mael 2005-03-16
    val op + = fn ({sec=sec1, usec=usec1} : time, {sec=sec2, usec=usec2}) =>
	let val usecs = usec1 + usec2 in
	    {sec  = sec1 - timebase + sec2 + usecs div 1000000,
	     usec = usecs mod 1000000}
	end 
*)
    and op - = fn ({sec=sec1, usec=usec1} : time, {sec=sec2, usec=usec2}) =>
	let val usecs = usec1 - usec2 
	    val secs  = sec1 - sec2 + usecs div 1000000
	in
	    if secs < 0 then raise Time 
	    else {sec = secs + timebase, usec = usecs mod 1000000}
	end handle Overflow => raise Time;

    val op <  = fn ({sec=sec1, usec=usec1} : time, {sec=sec2, usec=usec2}) =>
	(sec1 < sec2) orelse (sec1=sec2 andalso usec1 < usec2)
    and op <= = fn ({sec=sec1, usec=usec1} : time, {sec=sec2, usec=usec2}) =>
	(sec1 < sec2) orelse (sec1=sec2 andalso usec1 <= usec2)
    and op >  = fn ({sec=sec1, usec=usec1} : time, {sec=sec2, usec=usec2}) =>
	(sec1 > sec2) orelse (sec1=sec2 andalso usec1 > usec2)
    and op >= = fn ({sec=sec1, usec=usec1} : time, {sec=sec2, usec=usec2}) =>
	(sec1 > sec2) orelse (sec1=sec2 andalso usec1 >= usec2);

    fun compare (x, y: time) = 
	if x<y then LESS else if x>y then GREATER else EQUAL;

  end
