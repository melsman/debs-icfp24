structure Initial =
  struct
    type int0 = int
    type word0 = word

    exception Fail of string

    (* Real structure *)
    local
      fun get_posInf () : real = prim ("posInfFloat", ())
      fun get_negInf () : real = prim ("negInfFloat", ())
    in
      val posInf = get_posInf()
      val negInf = get_negInf()
    end

    (* Math structure *)
    local
      fun sqrt (r : real) : real = prim ("sqrtFloat", r)
      fun ln' (r : real) : real = prim ("lnFloat", r)
    in
      val ln10 = ln' 10.0 
      val NaN = sqrt ~1.0
    end

    (* Date structure *)
    local fun localoffset_ () : real = prim("sml_localoffset", ())
    in val localoffset = localoffset_ ()
(*       val fail_asctime = Fail "asctime" *)
       val fail_strftime = Fail "strftime"
    end

    (* Timer *)
    local
      type tusage = {gcSec : int,  gcUsec : int,
		     sysSec : int, sysUsec : int,
		     usrSec : int, usrUsec : int}
      fun getrealtime_ () : {sec : int, usec : int} =
	prim("sml_getrealtime", ())
(*      fun getrutime_ () : tusage = prim("sml_getrutime", ()) *)
    in val initial_realtime = getrealtime_ ()
       val initial_rutime :tusage =
           {gcSec=0, gcUsec=0,
	    sysSec=0, sysUsec=0,
	    usrSec=0, usrUsec=0}
         (*getrutime_ ()*)
    end 

    local
      val printer : (string -> unit) ref = 
          ref(fn(s:string) => prim("printStringML", s))
      fun !(x: 'a ref): 'a = prim ("!", x) 
      infix 3 :=
      fun (x: 'a ref) := (y: 'a): unit = prim (":=", (x, y)) 
    in
      fun printer_set p =
          printer := p
      fun printer_get() = !printer
    end 
  end
