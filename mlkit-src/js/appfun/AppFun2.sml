signature APP_ARG = sig
  val codemirror_module  : string
  val application_title  : string
  val application_logo   : string
  val demoinput          : string option
  val compute            : string -> string -> unit   (* [compute f content] output on stdout goes to the output area *)
  val computeLabel       : string
  val about              : unit -> Js.elem
  val script_paths       : string list
  val onloadhook         : {out: string -> unit} -> unit
  val syntaxhighlight    : bool
  val dropboxKey         : string option
  val fileExtensions     : string list
  val rightPane          : (unit -> Js.elem) option
end

functor AppFun(X : APP_ARG) : sig end =
struct

  open Js.Element
  infix &

  fun scrollDown e =
      JsCore.exec1 {stmt="t.scrollTop = t.scrollHeight;", arg1=("t",JsCore.fptr),res=JsCore.unit}
      (Js.Element.toForeignPtr e)

  fun userAgent() =
      JsCore.exec0{stmt="return navigator.userAgent;",res=JsCore.string} ()

  val agent = String.translate (Char.toString o Char.toLower) (userAgent())
  val touchDevices = ["ipod", "ipad", "iphone", "series60", "symbian", "android", "windows ce", "blackberry"]

  fun touchScreen a =
      let fun has s = String.isSubstring s a
      in List.exists (fn s => String.isSubstring s a) touchDevices
      end

  fun serverGet file =
      let val file = file ^ "?_=" ^ Real.toString (Time.toReal(Time.now())) (* avoid cache *)
          open Js.XMLHttpRequest
          val r = new()
          val () = openn r {method="GET",url=file,async=false}
          val () = send r NONE
      in case response r of
             SOME res => res
           | NONE => raise Fail ("serverGet failed on file " ^ file)
      end

  val outarea = taga0 "textarea" [("readonly","readonly")]
  val outareaDiv = taga "div" [("class","textareacontainer")] outarea
  val logarea = taga0 "textarea" [("readonly","readonly")]
  val logareaDiv = taga "div" [("class","textareacontainer")] logarea
  val clearoutbutton = taga0 "input" [("type","button"),("value","Clear Output")]

  val nodropboxPng = "nodropbox.png"
  val dropboxPng = "dropbox.png"
  val notifyAreaElem = taga "div" [("class","notify_area")] ($"welcome!")

  val dropboxAreaElem = taga0 "img" [("src",nodropboxPng),("class","dropbox_area")]
  fun setNoDropboxPng() = Js.setAttribute dropboxAreaElem "src" nodropboxPng
  fun setDropboxPng() = Js.setAttribute dropboxAreaElem "src" dropboxPng

  local
    val notifyTimeout = ref NONE
    fun setAttr e opacity color =
        Js.setAttribute e "style" ("opacity:" ^ Real.toString opacity ^ "; background-color:" ^ color ^ ";")
    fun clearNotification e =
        (Js.setAttribute e "style" "opacity:0.0;";
         notifyTimeout := NONE)
    fun fadeNotification color e opacity () =
        if opacity < 0.0 then clearNotification e
        else
          (setAttr e opacity color;
           notifyTimeout := SOME(Js.setTimeout 50 (fadeNotification color e (opacity-0.02))))

    val Error = "#dd8888"
    val Warning = "#dddd88"
    val Confirm = "#88dd88"

    fun notify0 color e s =
      (case !notifyTimeout of
           SOME tid => Js.clearTimeout tid
         | NONE => ();
       Js.innerHTML e s;
       setAttr e 1.0 color;
       notifyTimeout := SOME(Js.setTimeout 3000 (fadeNotification color e 0.98)))
  in
    val notify_err = notify0 Error notifyAreaElem
    val notify_errE = notify0 Error
    val notify_warn = notify0 Warning notifyAreaElem
    val notify = notify0 Confirm notifyAreaElem
  end

  val outRef : (string -> unit) ref = ref (fn _ => raise Fail "outRef not initialized")
  fun out s = !outRef s

  fun whileSome f g =
      case f() of
          SOME x => (g x; whileSome f g)
        | NONE => ()

  fun clearoutarea () =
      whileSome (fn() => Js.firstChild outarea)
                (fn e => Js.removeChild outarea e)

  fun outfun s =
      (Js.appendChild outarea (Js.createTextNode s);
       scrollDown outarea)

  fun clearlogarea () =
      whileSome (fn() => Js.firstChild logarea)
                (fn e => Js.removeChild logarea e)

  fun log0 s =
      let val s = Date.fmt "%H:%M:%S" (Date.fromTimeLocal(Time.now())) ^ ": " ^ s ^ "\n"
      in Js.appendChild logarea (Js.createTextNode s)
       ; scrollDown logarea
      end

  fun log s = (notify s; log0 s)
  fun logerr s = (notify_err s; log0 s)
  fun logwarn s = (notify_warn s; log0 s)

  val topelem = Js.documentElement Js.document

  fun appendStyleLink path =
      case Js.firstChild topelem of
          SOME head =>
          Js.appendChild head (taga0 "link" [("rel","stylesheet"), ("href", path)])
        | NONE => raise Fail "appendStyleLink"

  fun appendIconLink path =
      case Js.firstChild topelem of
          SOME head =>
          Js.appendChild head (taga0 "link" [("rel","shortcut icon"), ("type","image/x-icon"), ("href", path)])
        | NONE => raise Fail "appendStyleLink"

  fun appendScript path =
      case Js.firstChild topelem of
          SOME head =>
          Js.appendChild head (taga0 "script" [("type","text/javascript"), ("src", path)])
        | NONE => raise Fail "appendScript"

  fun cleanupBody () =
      case Js.firstChild topelem of
          SOME head =>
          (case Js.nextSibling head of
               SOME goodbody =>
               (case Js.nextSibling goodbody of
                    SOME badbody => Js.removeChild topelem badbody
                  | NONE => raise Fail "cleanupBody")
             | NONE => raise Fail "cleanupBody2")
        | NONE => raise Fail "cleanupBody3"

  fun createBody () =
      case Js.firstChild topelem of
          SOME head =>
          ((case Js.nextSibling head of
                SOME body => Js.removeChild topelem body
              | NONE => ());
           Js.appendChild topelem (taga0 "body" [("class","claro"), ("id", "body")]))
        | NONE => raise Fail "createBody"

  val () = appendStyleLink "dijit/themes/claro/claro.css"
  val () = appendStyleLink "js/codemirror/codemirror.css"
  val () = appendScript "js/codemirror/sml.js"
  val () = appendStyleLink "appfunstyle.css"
  val () = appendIconLink "favicon.ico"
  val () = createBody ()

  fun getElem id : Js.elem =
      case Js.getElementById Js.document id of
          SOME e => e
        | NONE => raise Fail "getElem"

  val () = List.app appendScript X.script_paths

  type editor =
       {get: unit -> string,
        set: string -> unit}

  fun mkEditor inarea : editor =
      if not X.syntaxhighlight orelse touchScreen agent then
        {get=fn() => Js.value inarea,
         set=fn s => case Js.firstChild inarea of
                       SOME c => Js.replaceChild inarea ($s) c
                     | NONE => Js.appendChild inarea ($s)
        }
      else
      let (*val kind = X.codemirror_module
          val tokenizefile =
              "../contrib/" ^ kind ^ "/js/tokenize" ^ kind ^ ".js"
          val parsefile =
              "../contrib/" ^ kind ^ "/js/parse" ^ kind ^ ".js"
          val stylefile =
              "js/codemirror/dist/contrib/" ^ kind ^ "/css/" ^ kind ^ "colors.css"
          *)
          val properties =
              let open CodeMirror.EditorProperties
                  val t = empty()
              in textWrapping t true
               ; lineNumbers t true
(*
               ; path t "js/codemirror/"
               ; parserfiles t [tokenizefile,parsefile]
               ; stylesheets t [stylefile]
*)
               ; height t "100%"
               ; width t "100%"
               ; mode t "sml"
               ; t
              end
          val ed = CodeMirror.newEditor {textarea=inarea, properties=properties}
      in {get=fn () => CodeMirror.getValue ed,
          set=fn s => CodeMirror.setValue ed s}
      end

  fun exec_print (f:'a -> unit) (v:'a) : string =
      let val p_old = Control.printer_get()
          val buf : string list ref = ref nil
          fun p_new s = buf := (s :: !buf)
          val () = Control.printer_set p_new
          val () = f v handle _ => ()
          val res = String.concat(rev(!buf))
      in Control.printer_set p_old;
         res
      end

  fun compileAndRunEditor f (editor:editor) =
      let val res = exec_print (X.compute f) (#get editor ())
      in out res
      end

  open Dojo infix >>=

  fun noop() = ()
  fun put s () = outfun (s^"\n")

  val logo = taga0 "img" [("src", X.application_logo),("height","30px"),("alt",X.application_title)]

  val menuStyle = ("style","border:0;padding:2;")

  fun qq s = "'" ^ s ^ "'"

  infix ^^
  fun "0" ^^ p = p
    | p1 ^^ p2 = p1 ^ "/" ^ p2

  structure Files = struct
    type filename = string
    type dir = string

    fun okExt s = List.exists (fn s' => s = s') X.fileExtensions

    fun okFolderName n =
        size n > 0 andalso
        Char.isAlpha (String.sub(n, 0)) andalso
        CharVector.all (fn c => Char.isAlphaNum c orelse c = #"_" orelse c = #"-") n

    fun okFileName n =
        case String.fields (fn c => c = #".") n of
            [bn,ext] => okFolderName bn andalso okExt ext
          | _ => false

    fun okFolderPath p =
        p = "0" orelse
        let val fields = String.fields (fn c => c = #"/") p
        in List.all okFolderName fields
        end

    fun okFilePath p =
        let val fields = String.fields (fn c => c = #"/") p
        in case rev fields of
               h :: tl => okFileName h andalso List.all okFolderName tl
             | _ => false
        end

    (* Three containers to keep in sync: allfiles, GUI filetreestore and dropbox filesTable!!
     *
     * - The containers allfiles and filetreestore are always in sync;
     *   this invariant is maintained by the functions in this
     *   structure.
     * - The variable current contains the current selected editor tab.
     * - The filesInTabs variable contains all the "loaded" files in tabs.
     * - The dropbox filesTable is kept in sync with the other
     *   containers using autosave and autoload.
     *
     * There is a reserved folder called Server. The content of the Server folder is
     * determined by the file otests/content on the server. Files and folders in the
     * Server folder are read-only, meaning that modifications to the files are not
     * saved.
     *)

    val allfiles : filename list ref = ref nil                (* long names *)
    val alldirs : dir list ref = ref ["0"]                    (* long names *)
    val fileStore : Dropbox.FileStore.filestore option ref = ref NONE
    val current : filename ref = ref "0"                      (* long name *)
    val filesInTabs : (filename*string ref*editor) list ref = ref nil

    fun splitPath p =
        if p = "0" then (p,NONE)
        else let val fields = String.fields (fn c => c = #"/") p
             in case rev fields of
                    [ n ] => if okFileName n then ("0",SOME n)
                             else (n,NONE)
                  | n :: tl => if okFileName n then (String.concatWith "/" (rev tl), SOME n)
                               else (p,NONE)
                  | _ => raise Fail "impossible: splitPath"
             end

    fun splitFolderPath p =
        if p = "0" then (p,NONE)
        else let val fields = String.fields (fn c => c = #"/") p
             in case rev fields of
                    [ n ] => if okFolderName n then ("0",SOME n)
                             else (n,NONE)
                  | n :: tl => if okFolderName n then (String.concatWith "/" (rev tl), SOME n)
                               else (p,NONE)
                  | _ => raise Fail "impossible: splitFolderPath"
             end

    fun currentFolder() =
        #1(splitPath(!current))
    fun currentFile() =
        if okFilePath (!current) then SOME (!current)
        else NONE
    fun currentIsFolder() =
        if okFolderPath (!current) then SOME(!current)
        else NONE

    fun fileExists name = List.exists (fn x => x = name) (!allfiles)
    fun folderExists name = List.exists (fn x => x = name) (!alldirs)

    fun isServerPath p =
        case String.tokens (fn c => c = #"/") p of
            "Server" :: _ => true
          | _ => false

    fun isDropboxPath p =
        case String.tokens (fn c => c = #"/") p of
            "Dropbox" :: _ => true
          | _ => false

    local
      (* [loadFile fts filename] loads an individual file in Dropbox and adds it to
       * the FileTreeStore. *)
      fun loadFile fts filename =
          let fun loadDir p n =
                  let val d = p ^^ n
                  in if List.exists (fn d' => d = d') (!alldirs) then ()
                     else (treeStoreAdd fts [("id",d),("parent",p),("name",n),("kind","folder")];
                           alldirs := d :: !alldirs)
                  end
              fun loadDirs name =
                  let val fields = String.fields (fn c => c = #"/") name
                      fun loop d [n] = if okFileName n then SOME (d,n)
                                       else (loadDir d n; NONE)
                        | loop d (n::tl) = (loadDir d n; loop (d^^n) tl)
                        | loop _ _ = raise Fail "loadDirs.impossible"
                  in loop "0" fields
                  end
          in case loadDirs filename of
                 NONE => ()
               | SOME (p,n) => (treeStoreAdd fts [("id",filename),("parent",p),("name",n),("kind","leaf")];
                                allfiles := filename :: !allfiles)
          end
    in

      (* [load c fts] loads files from Dropbox and updates FileTreeStore *)
      fun load c fts =
          let val fs = Dropbox.FileStore.filestore c
              val () = fileStore := SOME fs
          in Dropbox.FileStore.all_files fs (List.app (loadFile fts))
          end
    end

    (* [loadFileContentFromServer f] loads the file f from the server *)
    fun loadFileContentFromServer f =
        case rev(String.tokens (fn c => c = #"/") f) of
            x :: _ => let val c = serverGet ("otests/" ^ x ^ "_")
                      in log ("loaded file " ^ qq f ^ " from server");
                         c
                      end
          | _ => raise Fail ("failed to load server file content for " ^ f)

    (* [loadFileContent filename cont] calls cont(SOME c) if the file filename
     * (with content c) is not already loaded in a tab. It calls cont(NONE)
     * if the file is already in a tab. Raises (Fail msg) in case of
     * error. *)

    fun loadFileContent filename (cont:string option->unit) : unit =
        if List.exists (fn (x,_,_) => x = filename) (!filesInTabs) then
          (current := filename; cont NONE)
        else if isServerPath filename then
          cont(SOME(loadFileContentFromServer filename))
        else case !fileStore of
                 SOME fs =>
                 Dropbox.FileStore.content fs filename (fn c =>
                     ( current := filename
                     ; log ("Loaded file " ^ qq filename)
                     ; cont(SOME c)
                     ))
               | NONE => raise Fail "loadFileContent.fileStore not set"

    fun treeStoreRemoveExceptServer fts id =
        if isServerPath id then ()
        else treeStoreRemove fts id

    fun clear fts closetab =
        let val () = List.app (treeStoreRemoveExceptServer fts) (!allfiles)
            val () = List.app (fn id => if id <> "0" then
                                          treeStoreRemoveExceptServer fts id
                                        else ()) (!alldirs)
        in alldirs := ["0"];
           allfiles := nil;
           current := "0";
           List.app (fn (f,_,_) => closetab f) (!filesInTabs);
           filesInTabs := nil
        end

    fun mkAbsPath n =
        case currentFolder() of
            "0" => n
          | d => d ^ "/" ^ n

    local

       val count = ref 0
       fun newFile0 fts content name =
           let val lname = mkAbsPath name
           in if isServerPath lname then
                raise Fail "You cannot create new files in the Server folder"
              else
                let val () = case !fileStore of
                                 SOME fs => Dropbox.FileStore.write_file fs lname content (fn {msg} =>
                                                log("Wrote file " ^ lname ^ " (" ^ msg ^ ")"))
                               | NONE => ()
                    val () = allfiles := lname :: !allfiles
                in treeStoreAdd fts [("id", lname),("parent",currentFolder()),("name",name),("kind","leaf")];
                   current := lname;
                   lname
                end
           end
       fun newFolder0 fts name =
           let val lname = mkAbsPath name
           in if isServerPath lname then
                raise Fail "You cannot create new folders in the Server folder"
              else
                let val () = case !fileStore of
                                 SOME fs => Dropbox.FileStore.mkdir fs lname (fn {msg} =>
                                                log("Created folder " ^ lname ^ " (" ^ msg ^ ")"))
                               | NONE => ()
                    val () = alldirs := lname :: !alldirs
                in treeStoreAdd fts [("id", lname),("parent",currentFolder()),("name",name),("kind","folder")];
                   lname
                end
           end
    in
        local
           fun suggest exists f =
               let val num = !count before count := !count + 1
                   val name = f num
               in if exists name then suggest exists f
                  else name
               end
        in
           fun suggestNewFileName base = suggest fileExists (fn num => base ^ "-" ^ Int.toString num ^ ".sml")
           fun suggestNewFolderName () = suggest folderExists (fn num => "Folder-" ^ Int.toString num)
        end
        fun newFile fts content name =
            if fileExists name then raise Fail "file already exists"
            else if not(okFileName name) then raise Fail "invalid new file name"
            else newFile0 fts content name
        fun newFolder fts name =
            if folderExists name then raise Fail "folder already exists"
            else if not(okFolderName name) then raise Fail "invalid new folder name"
            else newFolder0 fts name

        fun currentEditor () =
            case currentFile() of
                NONE => NONE
              | SOME f =>
                case List.find (fn (f',_,_) => f = f') (!filesInTabs) of
                    SOME t => SOME (f,#3 t)
                  | NONE => ( logerr "currentEditor: error"
                            ; NONE)
    end (*local*)

    fun showTab n =
        current := n

    (* [delete fts closetab] deletes the current folder or the current file *)
    fun delete fts closetab : unit =
        case currentIsFolder() of
            SOME "0" => notify_err "Cannot delete root folder"
          | SOME folder =>
            if isServerPath folder then
              logerr ("You cannot delete folders in the Server folder")
            else
            let val (tabsToKill,tabsToKeep) =
                    List.partition (fn (f,_,_) => String.isPrefix (folder^"/") f) (!filesInTabs)
                val (filesToDelete,filesToKeep) =
                    List.partition (fn f => String.isPrefix (folder^"/") f) (!allfiles)
                val (foldersToDelete,foldersToKeep) =
                    List.partition (fn f => f = folder orelse String.isPrefix (folder^"/") f) (!alldirs)
                fun deleteFile f =
                    case !fileStore of
                        SOME fs => Dropbox.FileStore.delete_file fs f (fn {msg} =>
                                      log0 ("Deleted file " ^ qq f ^ " (" ^ msg ^ ")")
                                   )
                      | NONE => ()
                fun deleteFolder f =
                    case !fileStore of
                        SOME fs => Dropbox.FileStore.delete_dir fs f (fn {msg} =>
                                     log0 ("Deleted folder " ^ qq f ^ " (" ^ msg ^ ")")
                                   )
                      | NONE => ()
            in current := "0"
             ; filesInTabs := tabsToKeep
             ; allfiles := filesToKeep
             ; alldirs := foldersToKeep
             ; List.app (treeStoreRemoveExceptServer fts) filesToDelete
             ; List.app (treeStoreRemoveExceptServer fts) foldersToDelete
             ; List.app (fn (f,_,_) => closetab f) tabsToKill
             ; List.app deleteFile filesToDelete
             ; List.app deleteFolder foldersToDelete
             ; log ("Deleted folder " ^ qq folder ^ " completely")
            end
          | NONE =>
            let val f = !current
            in if isServerPath f then
                 logerr "You cannot delete files in the Server folder"
               else
                 ( current := "0"
                 ; filesInTabs := List.filter (fn (f',_,_) => f' <> f) (!filesInTabs)
                 ; allfiles := List.filter (fn f' => f' <> f) (!allfiles)
                 ; treeStoreRemoveExceptServer fts f
                 ; closetab f
                 ; (case !fileStore of
                        SOME fs => Dropbox.FileStore.delete_file fs f (fn {msg} =>
                                     log ("Deleted file " ^ qq f ^ " (" ^ msg ^ ")")
                                   )
                      | NONE => ())
                 )
            end

    fun addTab filename md5 editor =
        filesInTabs := (filename,ref md5,editor) :: (!filesInTabs)

    fun saveFile (filename,md5ref,editor:editor) =
        let val c = #get editor ()
            val newMd5 = MD5.fromString c
        in if !md5ref = newMd5 then ()
           else if isServerPath filename then
             logwarn ("Modified server file " ^ qq filename ^ " not saved")
           else (case !fileStore of
                     SOME fs =>
                     Dropbox.FileStore.write_file fs filename c (fn {msg} =>
                         ( log ("Saved file " ^ qq filename ^ " (" ^ msg ^ ")")
                         ; md5ref := newMd5
                         ))
                   | NONE => ())
                handle _ => ()
        end

    fun autosave () =
        List.app saveFile (!filesInTabs)

    fun closeTab n =
        let val () =
                case currentFile() of
                    SOME n' => if n = n' then current := "0"
                               else ()
                  | NONE => ()
            val () =
                case List.find (fn (n',_,_) => n' = n) (!filesInTabs) of
                    SOME f => saveFile f
                  | NONE => ()
            val newFilesInTabs = List.filter (fn (n',_,_) => n' <> n) (!filesInTabs)
        in filesInTabs := newFilesInTabs
        end

    fun stripAbsolute a =
        if size a > 0 andalso String.sub(a,0) = #"/" then
          SOME(String.extract(a,1,NONE))
        else NONE

    fun move fts folderpath filename newfile =             (* new file either relative to folderpath or absolute *)
        let val (newfilepath,newfilename,newparent) =
                if okFilePath newfile then
                  case splitPath newfile of
                      (parent, SOME newfilename) =>
                      let val newparent = if parent = "0" then folderpath
                                          else folderpath ^^ parent
                      in (folderpath ^^ newfile, newfilename, newparent)
                      end
                    | _ => raise Fail "move.impossible: newfile is a file"
                else
                  case stripAbsolute newfile of
                      SOME path =>
                      if okFilePath path then
                        case splitPath path of
                            (newparent, SOME newfilename) => (path,newfilename,newparent)
                          | _ => raise Fail "move.impossible: newfile is a file"
                      else raise Fail ("Invalid target path " ^ qq newfile)
                    | NONE => raise Fail ("Invalid target path " ^ qq newfile)
            val filepath = folderpath ^^ filename
            val () = case (isDropboxPath filepath, isDropboxPath newfilepath) of
                         (true,true) => ()
                       | (false,false) => ()
                       | _ => raise Fail "Files cannot be moved to or from Dropbox paths"
            (*val () = log ("Moving file " ^ qq filepath ^ " into " ^ qq newfilepath)*)
        in if isServerPath newfilepath then raise Fail "Files cannot be moved to the server"
           else if fileExists newfilepath then raise Fail ("File " ^ qq newfilepath ^ " already exists")
           else if not(folderExists newparent) then raise Fail ("Target folder " ^ qq newparent
                                                                ^ " does not exist")
           else case List.find (fn (n,_,_) => n = filepath) (!filesInTabs) of
              SOME (_,_,editor) =>
              ( current := "0"
              ; filesInTabs := List.filter (fn (n,_,_) => n <> filepath) (!filesInTabs)
              ; allfiles := List.map (fn n => if n <> filepath then n else newfilepath) (!allfiles)
              ; treeStoreRemoveExceptServer fts filepath
              ; treeStoreAdd fts [("id", newfilepath),("parent",newparent),("name",newfilename),("kind","leaf")]
              ; (case !fileStore of
                     SOME fs =>
                       Dropbox.FileStore.move_file fs filepath newfilepath (fn {msg} =>
                         log ("Moved file " ^ qq filepath ^ " to "
                              ^ qq newfilepath ^ " (" ^ msg ^ ")")
                       )
                   | NONE => ())
              ; (newfilepath,#get editor())
              )
            | NONE => raise Fail "Impossible: cannot locate file in tab structure!"
        end (*handle X as Fail msg => (logerr msg; raise X)*)
  end (* structure Files *)

  val ftsServer =
      let val content = serverGet "otests/content"
          val content = String.translate (fn c => if Char.isSpace c then "" else String.str c) content
          val lines = String.tokens (fn c => c = #";") content
          fun processFiles folder files =
              let val files = String.tokens (fn c => c = #",") files
              in List.map (fn f => [("id",folder^"/"^f),("name",f),("kind","file"),("parent",folder)]) files
              end
          fun processLine line =
              case String.tokens (fn c => c = #"=") line of
                  [folder,files] =>
                  let val sfolder = "Server/"^folder
                  in [("id",sfolder),("name",folder),
                      ("kind","folder"),("parent","Server")]::
                     processFiles sfolder files
                  end
                | [] => []
                | _ => (logerr "syntax error in otests/content file"; [])
      in [("id","Server"),("name","Server"),("kind","folder"),("parent","0")] ::
         List.foldr (fn (l,a) => processLine l @ a) nil lines
      end

  fun addEditorTab (tabs,tmap) filename content =
      let val inarea = taga "textarea" [("style","border:0;")] ($content)
          val inputarea = taga "div" [("class","textareacontainer")] inarea
          val () = run (pane [("style","height:100%;"),("title",filename),("closable","true")] inputarea >>= (fn page =>
                        (set_onClose page (fn() => (Files.closeTab filename; true));
                         set_onShow page (fn() => Files.showTab filename);
                         addChild tabs page;
                         selectChild tabs page;
                         tmap := (filename,page) :: (!tmap);
                         ret ())))
          val editor = mkEditor inarea
          val md5 = MD5.fromString content
      in Files.addTab filename md5 editor
      end

  fun button s = taga "button" [("style","height:25px; width:100px;")] (tag "b" ($s))

  fun withDialog {caption: string, button=buttext, label: string,
                  intro:Js.elem option,
                  suggestion: string, validate: string -> 'a,
                  cont: 'a -> unit} : unit =
      let
        val msgArea = taga0 "span" [("class","notify_area2"),("style","opacity:0.0;top:0px;")]
        fun doit d s =
              let val t = validate s
              in (hideDialog d; cont t; true)
              end handle Fail msg => (notify_errE msgArea msg; true)
          val field = taga0 "input" [("type","text"),("value",suggestion)]
          val but = button buttext
          val intro = case intro of
                          SOME e => tag "p" e
                        | NONE => $""
          val content =
              taga "p" [("style","width:400px;")]
                   (intro &
                    tag "p" ($(label ^ ": ") & field) &
                    tag "p" (but & $ " " & msgArea))
          val dM = dialog [("title",caption)] content >>= (fn d =>
                   (Js.installEventHandler but Js.onclick (fn () => doit d (Js.value field));
                    showDialog d; ret () ))
      in run dM
      end

  fun confirmDialog caption label msg f =
      let val cancel = button "Cancel"
          val but = button label
          val content = taga "p" [("style","width:400px;")] (tag "p" msg & taga "p" [("style","text-align:center;")] (cancel & $" " & but))
          val dM = dialog [("title",caption)] content >>= (fn d =>
                   (Js.installEventHandler but Js.onclick (fn () => (hideDialog d; f(); true));
                    Js.installEventHandler cancel Js.onclick (fn () => (hideDialog d; true));
                    showDialog d; ret () ))
      in run dM
      end

  fun infoDialog buttonlabel caption content : unit =
      let val but = button buttonlabel
          val content = taga "p" [("style","width:500px;")] (content & taga "p" [("style","text-align:center;")] but)
          val dM = dialog [("title",caption)] content >>= (fn d =>
                   (Js.installEventHandler but Js.onclick (fn () => (hideDialog d; true));
                    showDialog d; ret () ))
      in run dM
      end

  val infoDialogOk = infoDialog "Ok"

  fun menuHandle_NewNamedFile tabsmap fts () : unit =
      let val content = "(* File created " ^ Date.toString(Date.fromTimeLocal (Time.now())) ^ " *)\n"
      in withDialog {caption="New File", button="Create", label="Name",
                     intro=NONE,
                     suggestion=Files.suggestNewFileName "Untitled",
                     validate=Files.newFile fts content,
                     cont=fn s => addEditorTab tabsmap s content}
      end

  fun menuHandle_MoveFile tabsmap fts closetab () : unit =
      let val path = !Files.current
          val intro = $("Files can be renamed or moved either using relative " ^
                        "paths ('..' is not supported) or using absolute paths " ^
                        "(starting with '/').")
      in case Files.splitPath path of
             (parentpath, SOME filename) =>
             withDialog {intro=SOME intro,
                         caption="Move/Rename File", button="Move", label="New name",
                         suggestion=filename,
                         validate=Files.move fts parentpath filename,
                         cont=fn(newfilepath,content) =>
                                 (closetab path;
                                  addEditorTab tabsmap newfilepath content)}
           | (folderpath, NONE) =>
             notify_err "Renaming of folders not supported"
(*
             case Files.splitFolderPath folderpath of
                (parentpath, SOME foldername) =>
                withDialog {caption="Move/Rename Folder", button="Move", label="New name",
                            suggestion=foldername,
                            validate=Files.move fts parentpath foldername,
                            cont=fn(newfolderpath,content) =>
                                    (closetabsWith folderpath;
                                     addEditorTab tabsmap newfilepath content)}
*)
      end

  fun menuHandle_FilesDelete fts closetab () : unit =
      let val msg =
              case Files.currentFile() of
                  SOME f => ("Do you really want to delete the file " ^
                             qq f ^ "?")
                | NONE => case Files.currentIsFolder() of
                              SOME f => ("Do you really want to delete the folder " ^
                                         qq f ^ " and all its containing files?")
                            | NONE => raise Fail "menuHandle_FilesDelete.impossible"
      in confirmDialog "Confirm Deletion" "Delete" ($msg) (fn () => Files.delete fts closetab)
      end

  fun menuHandle_Export () : unit = infoDialogOk "Files Export to Zip" ($"Not yet implemented")
  fun menuHandle_Import () : unit = infoDialogOk "Files Import from Zip" ($"Not yet implemented")

  fun menuHandle_NewFolder fts () : unit =
      withDialog {caption="New Folder", button="Create", label="Name",
                  intro=NONE,
                  suggestion=Files.suggestNewFolderName (),
                  validate=Files.newFolder fts,
                  cont=fn s => ()}

  fun treeHandle_LoadFile tabsmap selecttab (lname,name) : unit =
      if Files.okFolderPath lname then Files.current := lname
      else Files.loadFileContent lname
             (fn SOME content => addEditorTab tabsmap lname content
               | NONE => selecttab lname)

  fun menuHandle_OpenDemo tabsmap fts demo () =
      let val name = Files.suggestNewFileName "Demo"
          val path = Files.newFile fts demo name
      in addEditorTab tabsmap path demo
      end

  fun menuHandle_DropboxSignIn key () =
      let fun doit() =
              let val c = Dropbox.client key
              in Dropbox.authorize c
              end
      in if (!Files.allfiles = nil andalso !Files.alldirs = ["0"]) orelse Option.isSome(!Files.fileStore) then doit()
         else let val msg = $"Signing in to Dropbox will delete all application data created in this session. \
                             \If this is the first time you sign in to Dropbox from this application, you will \
                             \be asked to allow the application to store data in a special area of your Dropbox account."
              in confirmDialog "Dropbox Sign In" "Sign in" msg doit
              end
      end

  fun menuHandle_DropboxSignOut c fts closetab () =
      let val msg = $"Signing out of Dropbox will not delete any files in the Dropbox App folder. You will \
                     \always be able to sign in again using the \"Sign in\" entry in the Dropbox menu."
      in Files.autosave();
         confirmDialog "Dropbox Sign Out" "Sign out" msg
           (fn () => Dropbox.signOut c
               (fn () => (Files.fileStore := NONE;
                          Files.clear fts closetab;
                          log "Signed out of Dropbox";
                          setNoDropboxPng())))
      end

  fun menuHandle_CompileAndRun () =
      case Files.currentEditor() of
          SOME (f,e) => compileAndRunEditor f e
        | NONE => logerr "No file selected"

  fun poweredby () =
      let fun link l t () = taga "a" [("href",l), ("target","_blank")] ($t)
          val linkSMLtoJs = link "http://www.smlserver.org/smltojs" "SMLtoJs"
          val linkDojo = link "http://dojotoolkit.org/" "Dojo"
          val linkCodeMirror = link "http://codemirror.net" "CodeMirror"
          val linkDropboxAPIv2 = link "https://www.dropbox.com/developers/documentation/http/overview" "Dropbox API v2"
          val linkMLKitRep = link "https://github.com/melsman/mlkit" "Github MLKit Repository"
      in tag "p"
             ($"This IDE is based on " & linkSMLtoJs() &
              $", a Standard ML to JavaScript compiler. The front-end uses " & linkDojo() &
              $" and " & linkCodeMirror() & $". The IDE " &
              $" allows for the user to save source files in a personal Dropbox App folder using " &
              linkDropboxAPIv2() &
              $".") &
         tag "p"
             ($" The sources for this IDE are" &
              $" available by download from the " & linkMLKitRep() & $" and are distributed" &
              $" under the GPL2 license; some parts of the sources are also available under the MIT license." &
              $" For information about licenses, please consult the sources at the " &
              linkMLKitRep() & $".")
      end

  fun menu tabs fts closetab =
      Menu.mk [("region", "center"),menuStyle] >>= (fn (w_left, m_left) =>
      Menu.menu m_left "File" >>= (fn m_file =>
      Menu.item m_file ("New file", SOME EditorIcon.newPage, menuHandle_NewNamedFile tabs fts) >>= (fn () =>
      Menu.item m_file ("New folder", SOME Icon.folderClosed, menuHandle_NewFolder fts) >>= (fn () =>
      Menu.item m_file ("Move", SOME EditorIcon.paste, menuHandle_MoveFile tabs fts closetab) >>= (fn () =>
      Menu.item m_file ("Delete", SOME EditorIcon.delete, menuHandle_FilesDelete fts closetab) >>= (fn () =>
      Menu.item m_file ("Export (zip)", SOME EditorIcon.indent, menuHandle_Export) >>= (fn () =>
      Menu.item m_file ("Import (zip)", SOME EditorIcon.outdent, menuHandle_Import) >>= (fn () =>
      (case X.demoinput of NONE => ret () | SOME demo => Menu.item m_file ("Open Demo File", NONE, menuHandle_OpenDemo tabs fts demo)) >>= (fn () =>
      (case X.dropboxKey of NONE => ret () | SOME key =>
       Menu.menu m_left "Dropbox" >>= (fn m_dropbox =>
       (let val c = Dropbox.client key
            val () = if Dropbox.isAuthorized c then
                       (Files.load c fts;
                        Dropbox.dropboxUid c (fn uid => log ("Authorized to use " ^ uid ^ "'s Dropbox App Folder"));
                        setDropboxPng())
                     else log "Not Dropbox authorized"
            val m = Menu.item m_dropbox ("Sign in", SOME EditorIcon.createLink, menuHandle_DropboxSignIn key)
                              >>= (fn () => Menu.item m_dropbox ("Sign out", SOME EditorIcon.unlink, menuHandle_DropboxSignOut c fts closetab))
        in run m
        end;
        ret ()))) >>= (fn () =>
      Menu.item m_left (X.computeLabel, NONE, menuHandle_CompileAndRun) >>= (fn () =>
      Menu.item m_left ("Clear output", NONE, clearoutarea) >>= (fn () =>
      pane [("region", "left"),("style","padding:0;padding-right:10;background-color:#eeeeee;")] logo >>= (fn logo =>
      Menu.mk [("region", "right"),menuStyle] >>= (fn (w_right, m_right) =>
      Menu.menu m_right "Help" >>= (fn m_help =>
      Menu.item m_help ("About", SOME EditorIcon.newPage, fn() => infoDialogOk ("About " ^ X.application_title) (X.about())) >>= (fn () =>
      Menu.item m_help ("Powered by...", SOME EditorIcon.newPage, fn() => infoDialogOk "Powered by..." (poweredby())) >>= (fn () =>
      layoutContainer [("region", "top"),("style","height:30px;")] [logo, w_left, w_right]
      )))))))))))))))))

  val everything =
      advTabContainer [("region", "top"),("splitter","true"),("style","height:70%;border:0;"),("tabPosition","bottom")] >>= (fn (tabsmap,{select=selecttab,close=closetab}) =>
      treeStore ([("id", "0"),("name","/"),("kind","folder")]::ftsServer) >>= (fn fts =>
      tree [("region", "left"),("splitter","true"),("style","width:20%;")] "0" (treeHandle_LoadFile tabsmap selecttab) fts >>= (fn left =>
      menu tabsmap fts closetab >>= (fn top =>
      pane [("title","Output")] outareaDiv >>= (fn outputpane =>
      pane [("title","Message Log")] logareaDiv >>= (fn logpane =>
      tabContainer [("region", "center"),("style","height:30%;"),("tabPosition","bottom")] [outputpane,logpane] >>= (fn centerbot =>
      borderContainer [("region", "center")] [#1 tabsmap,centerbot] >>= (fn center =>
      (case X.rightPane of
           SOME generator => pane [("region", "right"), ("splitter","true")] (generator()) >>= (fn p => ret [p])
         | NONE => ret [])  >>= (fn rights =>
      borderContainer [("style", "height: 100%; width: 100%;")] ([left,top,center] @ rights)
      )))))))))

  val () = Js.appendChild (getElem "body") notifyAreaElem
  val () = Js.appendChild (getElem "body") dropboxAreaElem

  val () = attachToElement (getElem "body") everything (fn () => ())

  fun onload() =
      let
        val () = cleanupBody()
        val () = outRef := outfun
        val () = X.onloadhook {out=out}
        val _ = Js.setInterval 10000 Files.autosave
      in ()
      end

  fun setWindowOnload (f: unit -> unit) : unit =
      let open JsCore infix ==>
      in exec1{arg1=("a", unit ==> unit),
               stmt="return window.onload=a;",
               res=unit} f
      end

  val () = setWindowOnload onload

end
