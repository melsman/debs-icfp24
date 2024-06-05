structure CompileSMLNJ_110_40 : COMPILE =
  struct
(*
    fun compile src =
      let val {base,ext} = OS.Path.splitBaseExt src
      in case ext
	   of SOME "sml" =>
	     let
	       val src_smlnj = base ^ "_smlnj.sml"
	       val target = base ^ "_smlnj.exe"
	       val cmd = 
		 ("echo 'use \"" ^ src_smlnj
		  ^ "\"; SMLofNJ.exportFn(\"" ^ target ^ "\", fn _ => (doit();OS.Process.success));' | sml")
	     in if OS.Process.system cmd = OS.Process.success then 
		  let val os = TextIO.openOut target
		      val _ = TextIO.output(os, "#!/bin/sh\nsml @SMLload=" ^ target ^ ".x86-linux $*")
		      val _ = TextIO.closeOut os
		      val _ = OS.Process.system("chmod a+x " ^ target)
		  in SOME target
		  end 
		else NONE 
	     end
	   | SOME _ => NONE
	   | NONE => NONE
      end handle _ => NONE
*)

    fun compile kitdir compileflags src opts =
      let 
	  val heap2execDir = kitdir ^ "/src/heap2exec/"
	  val heap2exec = heap2execDir ^ "heap2exec " ^ heap2execDir ^ "run-110.40.x86-linux"
	  val {base,ext} = OS.Path.splitBaseExt src
      in case ext
	   of SOME "sml" =>
	     let
	       val src_smlnj = base ^ "_smlnj.sml"
	       val target = base ^ "_smlnj-110.40.exe"
	       val exportCmd = 
		 ("echo 'use \"" ^ src_smlnj
		  ^ "\"; SMLofNJ.exportFn(\"" ^ target ^ "\", fn _ => (doit();OS.Process.success));' | sml-110.40")
	       val heap2execCmd = 
		  (heap2exec ^ " " ^ target ^ ".x86-linux " ^ target) 
	     in if (OS.Process.system exportCmd = OS.Process.success andalso
		    OS.Process.system heap2execCmd = OS.Process.success andalso
		    OS.Process.system("chmod a+x " ^ target) = OS.Process.success)
		  then SOME (src_smlnj,target)
		else NONE
	     end
	    | SOME "pm" => 
  	     let val src_smlnj = base ^ "_smlnj.cm"
	         val target = base ^ "_smlnj-110.40.exe"
		 val exportCmd = 
		   ("echo 'CM.make'\"'\"' \"" ^ src_smlnj
		    ^ "\"; SMLofNJ.exportFn(\"" ^ target ^ "\", fn _ => (Main.doit();OS.Process.success));' | sml-110.40")
		 val heap2execCmd = 
		    (heap2exec ^ " " ^ target ^ ".x86-linux " ^ target) 
	     in if (OS.Process.system exportCmd = OS.Process.success andalso
		    OS.Process.system heap2execCmd = OS.Process.success andalso
		    OS.Process.system("chmod a+x " ^ target) = OS.Process.success)
		  then SOME (src_smlnj,target)
		else NONE
	     end
	    | SOME _ => NONE
	    | NONE => NONE
      end handle _ => NONE
  end
	