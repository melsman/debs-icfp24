
structure TestReportLatex : TEST_REPORT =
  struct
    
    type runtime_line = {name: string, ok: bool, exesize: string,
			 exesize_stripped: string, size: int, rss: int, 
			 data: int, stk: int, exe: int,
			 real: Time.time, user: Time.time, sys: Time.time}

    val compout_lines : {name: string, match: bool option, success_as_expected: bool} list ref = ref nil
    val comptime_lines : {name: string, entries: (string * Time.time) list} list ref = ref nil
    val runtime_lines : runtime_line list ref = ref nil
    val runtime_bare_lines : (string * bool) list ref = ref nil
    val profile_lines : (string * bool) list ref = ref nil
    val gc_lines : (string * bool) list ref = ref nil
    val gengc_lines : (string * bool) list ref = ref nil
    val gc_prof_lines : (string * bool) list ref = ref nil
    val gengc_prof_lines : (string * bool) list ref = ref nil
    val tags_lines : (string * bool) list ref = ref nil
    val tags_prof_lines : (string * bool) list ref = ref nil
    val log_lines : string list ref = ref nil

    fun reset () = (runtime_lines := nil; runtime_bare_lines := nil; 
		    compout_lines := nil; comptime_lines := nil; 
		    profile_lines := nil; log_lines := nil;
		    gc_lines := nil; gc_prof_lines := nil;
		    gengc_lines := nil; gengc_prof_lines := nil;
		    tags_lines := nil; tags_prof_lines := nil)
      
    fun add_runtime_line l = runtime_lines := l :: !runtime_lines
    fun add_runtime_bare_line l = runtime_bare_lines := l :: !runtime_bare_lines
    fun add_profile_line l = profile_lines := l :: !profile_lines
    fun add_gc_line l = gc_lines := l :: !gc_lines
    fun add_gengc_line l = gengc_lines := l :: !gengc_lines
    fun add_gc_profile_line l = gc_prof_lines := l :: !gc_prof_lines
    fun add_gengc_profile_line l = gengc_prof_lines := l :: !gengc_prof_lines
    fun add_tags_line l = tags_lines := l :: !tags_lines
    fun add_tags_profile_line l = tags_prof_lines := l :: !tags_prof_lines
    fun add_comptime_line l = comptime_lines := l :: !comptime_lines
    fun add_compout_line l = compout_lines := l :: !compout_lines
    fun add_log_line l = log_lines := l :: !log_lines

    fun read_all s =
      let val is = TextIO.openIn s
      in let val res = TextIO.inputAll is
	 in TextIO.closeIn is; res
	 end handle _ => (TextIO.closeIn is; "could not read file `" ^ s ^ "'\n")
      end handle _ => ("could not open or close file `" ^ s ^ "'\n")

    fun kitversion kitexe =
      if OS.Process.isSuccess(OS.Process.system (kitexe ^ " --version > KITversion")) then
	read_all "KITversion"
      else "failure while executing `" ^ kitexe ^ " --version'\n"

    (* Get entry for a UNIX environment variable *)
(*    fun get_env_var env_name = 
      case OS.Process.getEnv env_name
	of SOME s => s 
	 | NONE => (* let's try something else *)
	    read_all "/etc/hostname" *)

    fun machine() = case OS.Process.getEnv "HOSTNAME"
                    of SOME x => x
                     | NONE => "localhost"

    fun latex file =
      if OS.Process.isSuccess(OS.Process.system ("pdflatex " ^ file)) then ()
      else print "Latex error.\n"

    type comptime_table_line = {name:string, total:Time.time, entries: (string * Time.time * real) list}
    type comptime_table = comptime_table_line list

    fun process_comptime_line({name: string, entries: (string * Time.time) list}) : comptime_table_line =
      let val total = foldl Time.+ Time.zeroTime (map #2 entries)
	  fun pct t = 100.0 * (Time.toReal t) / (Time.toReal total)
      in {name=name, total=total, entries = map (fn (s,t) => (s,t,pct t)) entries}
      end

    (*invariant: compilation of all programs results in the same entries, in the same order *)
    fun split_comptime_table(table: comptime_table) : comptime_table list =
      let fun split n [] acc = (rev acc, [])
	    | split n (l as e::es) acc = if n <= 0 then (rev acc, l)
					 else split (n-1) es (e::acc)
	  val oksize=6
	  fun split_table [] = ([],[])
	    | split_table ({name,total,entries}::rest) =
	    let val (table_lines, table_lines') = split_table rest 
	        val (entries, entries') = split oksize entries []
	    in ({name=name,total=total,entries=entries}::table_lines,
		{name=name,total=total,entries=entries'}::table_lines')
	    end

	  fun size_table ([]:comptime_table) = ~1
	    | size_table (e::_) = List.length (#entries e)
	    
	  fun loop (t, acc) = if size_table t > oksize then 
	                        let val (t,rest) = split_table t
				in loop(rest, t::acc)
				end
			      else rev(t::acc)
      in loop(table, [])
      end

    fun split_lines xx = 
      let val l = length xx
	  val ld3 = l div 3
      in if l < 6 then (xx,[],[])
	 else let val xx1 = List.take(xx,ld3)
		  val rest = List.drop(xx, ld3)
		  val xx2 = List.take(rest,ld3)
		  val xx3 = List.drop(rest,ld3)
	      in (xx1,xx2,xx3)
	      end
      end 

    fun pr_ok true = "ok"
      | pr_ok false = "err"

    fun verb n = "\\verb+" ^ n ^ "+"

    fun export {errors:int, testfile_string: string, kitexe: string} : unit =
      let val texfile = "test_report.tex"
	  val os = TextIO.openOut texfile
	  fun out s = TextIO.output(os,s)
	  fun outln s = out(s^"\n")

	  fun beginenv env = outln ("\\begin{" ^ env ^ "}")
	  fun beginenv' (env,s) = outln ("\\begin{" ^ env ^ "}" ^ s)
	  fun endenv env = outln("\\end{" ^ env ^ "}")
	  fun section sec = outln("\\section{" ^ sec ^ "}")
	  fun subsection sec = outln("\\subsection{" ^ sec ^ "}")

	  fun outresult 0 = outln "No errors were found during the test."
	    | outresult 1 = outln "I found one error; see the Test Log section for details." 
	    | outresult n = outln ("I found " ^ Int.toString n ^ " errors; see the Test Log Section for details.")

	  fun header() =
	    (outln "\\documentclass[10pt]{article}";
	     outln "\\usepackage{a4wide}";
	     outln "\\textwidth 170mm";
	     outln "\\title{ML Kit Test Report}";
	     outln "\\author{Author: The ML Kit Tester}";
	     beginenv "document";
	     outln "\\maketitle")

	  fun abstract() =
	    let val kitexe' = concat (map (fn #"_" => "\\_" | a => str a) (explode kitexe))
	    in
	    (beginenv "abstract";
	     outln "This test report is generated by the ML Kit Tester, a program for finding";
	     outln "bugs in the ML Kit, for finding inefficiencies in the ML Kit compiler, and";
	     outln "for benchmarking generated executables. All tests were executed on ";
	     outln ("{\\bf " ^ machine() ^ "}.");
	     outln ("Here is the output from executing {\\tt " ^ kitexe' ^ " --version}:");
	     beginenv "quote";
	     beginenv "verbatim";
	     out (kitversion kitexe);
	     endenv "verbatim";
	     endenv "quote";
	     outresult errors;
	     endenv "abstract")
	    end

	  fun compout_section [] = ()
	    | compout_section (l : {name:string, success_as_expected:bool,match:bool option} list) =
	    let 
	      val header = "\\hline Source & Compare & Success as expected \\\\ \\hline" 
		
	      fun pr_ok_opt NONE = "--"
		| pr_ok_opt (SOME ok) = pr_ok ok
	      fun line {name,match,success_as_expected} = 
		(verb name ^ " & " ^ pr_ok_opt match ^ " & " ^
		 pr_ok success_as_expected ^ " \\\\ \\hline")

	    in section "Comparison of Compiler Messages";
	       outln "This section compares compiler messages (e.g., elaboration results) with";
	       outln "expected compiler messages (column ``Compare''). The column ``Success as expected'' shows if";
	       outln "compilation succeeded or failed as expected.";
	       outln "";
	       outln "\\vspace{4mm}";
	       beginenv' ("tabular","{|l|c|c|}");
	       outln header;
	       app (outln o line) l;
	       endenv "tabular"
	    end

	  fun entriesOfL (nil:comptime_table,(_,acc)) = acc
	    | entriesOfL ({entries,...}::l,(n,acc)) =
	      let val n' = length entries
	      in entriesOfL(l,
			    if n' > n then (n',entries)
			    else (n,acc))
	      end

	  fun comptime_section [] = ()
	    | comptime_section(lines: {name: string, entries: (string * Time.time) list} list) =
	    let val table : comptime_table = map process_comptime_line lines
		val tables : comptime_table list = split_comptime_table table		  
		fun mktable [] = ()
		  | mktable (l as {entries,...}::l') =
		  let val entries = entriesOfL (l',(length entries,entries))
		      val header = foldl (fn (s,a) => a ^ " & " ^ s) "\\hline Source & Total" (map #1 entries) ^ "\\\\ \\hline"
		    fun entry (s, t, r) = Time.fmt 2 t ^ "/" ^ Real.fmt (StringCvt.FIX (SOME 1)) r
		    fun line {name,total,entries} =
		      foldl (fn (e,a) => a ^ " & " ^ entry e) (verb name ^ " & " ^ Time.fmt 2 total) entries ^ "\\\\ \\hline"
		    val tabularkind = foldl (fn (_,a) => a ^ "|c") "{|l|r" entries ^ "|}"
		  in 
		    outln "";
		    outln "\\vspace{4mm}";
		    beginenv' ("tabular",  tabularkind);
		    outln header;
		    app (outln o line) l;
		    endenv "tabular"
		  end
	    in
	      section "Timings of the Compiler";
	      outln "This section shows timings for the Kit compiler.";
	      outln "The times measured are the times used by different phases of the Kit for compiling";
	      outln "the source programs.";
	      outln "Timings are written ({\\em time}/{\\em pct}), where {\\em time} is the user";
	      outln "time (garbage collection time excluded) in seconds and {\\em pct} is the percentage";
	      outln "of time used in the phase compared to the time used for all the measured phases (the Total column).";
	      app mktable tables
	    end

	  fun execution_section	[] = ()
	    | execution_section (l : runtime_line list) =
	    let fun stack [] = ""
		  | stack [e] = e
		  | stack (e::l) = "$\\!\\!$\\begin{tabular}{c}" ^ foldl (fn (s,a) => a ^ " \\\\" ^ s) e l ^ "\\end{tabular}$\\!\\!$"
	        val header = "\\hline Source & Ok & " 
		  ^ stack ["Exec", "size"] ^ " & "
(*		  ^ stack ["Size of", "stripped", "exec."] ^ " & " *)
		  ^ stack ["Vm-", "Size"] ^ " & "
		  ^ stack ["Vm-", "RSS"] ^ " & "
		  ^ stack ["Vm-", "Data"] ^ " & "
		  ^ stack ["Vm-", "Stk"] ^ " & "
		  ^ stack ["Vm-", "Exe"] ^ " & "		  
		  ^ stack ["real", "time"] ^ " & "
		  ^ stack ["user", "time"] ^ " & "
		  ^ stack ["sys", "time"] ^ " \\\\ \\hline"

		fun report i = (* i is in kilobytes *)
		  if i > 10000 then Int.toString (i div 1000) ^ "M"
		  else Int.toString i ^ "K"

		fun line {name: string, ok: bool, exesize: string,
			  exesize_stripped: string, size: int, rss: int, 
			  data:int, stk:int, exe: int,
			  real: Time.time, user: Time.time, sys: Time.time} =
		  (verb name ^ " & " ^ pr_ok ok ^ (* " & " ^ exesize ^ *) " & " ^
		   exesize_stripped ^ " & " ^ report size ^ " & " ^ report rss ^ " & " ^ 
		   report data ^ " & " ^ report stk ^ " & " ^ report exe ^ " & " ^
		   Time.toString real ^ " & " ^ Time.toString user ^ " & " ^ Time.toString sys ^ "\\\\ \\hline")
	    in 
	      section "Measurements of Executables";
	      outln "This section shows static and dynamic properties of the generated executable files.";
	      outln "Sizes of executables are in bytes (measured after symbols from object files are stripped). ";
	      outln "Column {\\tt Vm-Size} shows the total size";
	      outln "of the process---including text, data, and stack. Column {\\tt Vm-RSS}";
	      outln "shows the resident set-size of the process, which is the total amount";
	      outln "of physical memory used by the task"; 
	      outln "Memory sizes and execution timings are found by reading periodically from";
	      outln "the {\\tt proc} filesystem, mounted on {\\tt /proc}.";
	      outln "The ``Ok'' column  shows if the output from running the executable";
	      outln "equals the expected output.";
	      outln "";
	      outln "\\vspace{4mm}";
	      outln "{\\small";
	      beginenv' ("tabular","{||l|r|r||r|r|r|r|r||r|r|r||}");
	      outln header;
	      app (outln o line) l;
	      endenv "tabular";
	      outln "}"
	    end
	  
	  local
	    val header = "\\hline Source & Ok \\\\ \\hline"
	    fun line (name, ok) = (verb name ^ " & " ^ pr_ok ok ^ "\\\\ \\hline")
	    fun table [] = ()
	      | table l = (beginenv' ("tabular","{|l|c|}");
			   outln header;
			   app (outln o line) l;
			   endenv "tabular")
	  in
	    fun exe_output_section [] = ()
	      | exe_output_section (l:(string * bool) list) =
	      let 
(*	        val header = "\\hline Source & Ok \\\\ \\hline"
		fun line (name, ok) = (verb name ^ " & " ^ pr_ok ok ^ "\\\\ \\hline")
		fun table [] = ()
		  | table l = (beginenv' ("tabular","{|l|c|}");
			       outln header;
			       app (outln o line) l;
			       endenv "tabular") 20/04/1999, Niels *)
		val (l1,l2,l3) = split_lines l
	      in 
		section "Comparison of Output from Executables";
		outln "This section shows if the output from execution equals the expected output.";
		outln "Entries for executables that are measured in Section ``Measurements of Executables''";
		outln "(if one such section exists) are not shown here.";
		outln "";
		outln "\\vspace{4mm}";
		table l1;
		table l2;
		table l3
	      end

	    fun profile_section [] = ()
	      | profile_section (l:(string * bool) list) =
	      let 
(*	        val header = "\\hline Source & Ok \\\\ \\hline"
		fun line (name, ok) = (verb name ^ " & " ^ pr_ok ok ^ "\\\\ \\hline")
		fun table [] = ()
		  | table l = (beginenv' ("tabular","{|l|c|}");
			       outln header;
			       app (outln o line) l;
			       endenv "tabular") 20/04/1999, Niels*)
		val (l1,l2,l3) = split_lines l
	      in 
		section "Profiling";
		outln "This section shows tests of the compiler with profiling enabled.";
		outln "See Section ``Log File'' for details of errors.";
		outln "";
		outln "\\vspace{4mm}";
		table l1;
		table l2;
		table l3
	      end

	    fun gc_section [] = ()
	      | gc_section (l:(string * bool) list) =
	      let
		val (l1,l2,l3) = split_lines l
	      in
		section "Garbage Collection";
		outln "This section shows tests of the compile with garbage collection enabled.";
		outln "See Section ``Log File'' for details of errors.";
		outln "";
		outln "\\vspace{4mm}";
		table l1;
		table l2;
		table l3
	      end

	    fun gc_prof_section [] = ()
	      | gc_prof_section (l:(string * bool) list) =
	      let
		val (l1,l2,l3) = split_lines l
	      in
		section "Garbage Collection and Profiling";
		outln "This section shows tests of the compile with garbage collection and profiling enabled.";
		outln "See Section ``Log File'' for details of errors.";
		outln "";
		outln "\\vspace{4mm}";
		table l1;
		table l2;
		table l3
	      end

	    fun gengc_section [] = ()
	      | gengc_section (l:(string * bool) list) =
	      let
		val (l1,l2,l3) = split_lines l
	      in
		section "Generational Garbage Collection";
		outln "This section shows tests of the compile with generational garbage collection enabled.";
		outln "See Section ``Log File'' for details of errors.";
		outln "";
		outln "\\vspace{4mm}";
		table l1;
		table l2;
		table l3
	      end

	    fun gengc_prof_section [] = ()
	      | gengc_prof_section (l:(string * bool) list) =
	      let
		val (l1,l2,l3) = split_lines l
	      in
		section "Generational Garbage Collection and Profiling";
		outln "This section shows tests of the compile with generational garbage collection and profiling enabled.";
		outln "See Section ``Log File'' for details of errors.";
		outln "";
		outln "\\vspace{4mm}";
		table l1;
		table l2;
		table l3
	      end

	    fun tags_section [] = ()
	      | tags_section (l:(string * bool) list) =
	      let
		val (l1,l2,l3) = split_lines l
	      in
		section "Tagging";
		outln "This section shows tests of the compile with tagging enabled (garbage collection disabled).";
		outln "See Section ``Log File'' for details of errors.";
		outln "";
		outln "\\vspace{4mm}";
		table l1;
		table l2;
		table l3
	      end

	    fun tags_prof_section [] = ()
	      | tags_prof_section (l:(string * bool) list) =
	      let
		val (l1,l2,l3) = split_lines l
	      in
		section "Tagging and Profiling";
		outln "This section shows tests of the compile with tagging and profiling enabled (garbage collection disabled).";
		outln "See Section ``Log File'' for details of errors.";
		outln "";
		outln "\\vspace{4mm}";
		table l1;
		table l2;
		table l3
	      end
	  end
 
	  fun testfile_section() =
	    (section "Test File";
	     outln "Here is the test file for this test report:";
	     beginenv "verbatim";
	     outln testfile_string;
	     endenv "verbatim")

	  fun logsection (lines : string list) =
	    (outln "\\twocolumn";
	     section "Test Log";
	     outln "Here is the log for the test:";
	     beginenv "verbatim";
	     app outln lines;
	     endenv "verbatim")

      in
	header(); 
	abstract(); 
	compout_section(rev(!compout_lines));
	comptime_section(rev(!comptime_lines));
	execution_section(rev(!runtime_lines));
	exe_output_section(rev(!runtime_bare_lines));
	profile_section(rev(!profile_lines));
	tags_section(rev(!tags_lines));
	tags_prof_section(rev(!tags_prof_lines));
	gc_section(rev(!gc_lines));
	gc_prof_section(rev(!gc_prof_lines));
	gengc_section(rev(!gc_lines));
	gengc_prof_section(rev(!gc_prof_lines));
	testfile_section();
	logsection (rev(!log_lines)); 
	endenv "document"; 
	TextIO.closeOut os; 
	latex texfile
      end
  end
