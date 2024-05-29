structure CompileSMLNJ : COMPILE =
  struct
    val sml_path = "sml"          (* was /usr/local/smlnj/bin/sml *)
    val mlbuild_path = "ml-build" (* was /usr/local/smlnj/bin/ml-build *)
    val os = "linux"              (* was darwin *)
    fun compile {env:(string*string)list,flags:string, src:string} =
      let val {base,ext} = OS.Path.splitBaseExt src
          val {dir,file} = OS.Path.splitDirFile base
	  val cmsrc = file ^ ".cm"                    (* assume existence of a cm-file *)
	  fun comp src =
	      let val cmd = "(cd " ^ dir ^ "; " ^ mlbuild_path ^ " " ^ cmsrc ^ " Main.main)"   (* ignore flags and environment *)
                  val target = sml_path ^ " @SMLload=" ^ base ^ ".amd64-" ^ os
	      in  print ("Executing: '" ^ cmd ^ "'\n")
	        ; if OS.Process.isSuccess(OS.Process.system cmd) then SOME target
		  else NONE
	      end
      in case ext
	   of SOME "sml" => comp src
	    | SOME "mlb" => comp src
	    | _ => NONE
      end

    fun version () =
        FileUtil.trimWS(FileUtil.systemOut (sml_path ^ " @SMLversion"))
        handle X => ("Failed to extract smlnj version; " ^ exnMessage X)
  end
