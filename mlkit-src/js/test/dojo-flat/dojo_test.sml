structure Test = struct
open Dojo infix >>=

fun log s = JsCore.call1 ("console.log",JsCore.string,JsCore.unit) s

local val postruns = ref nil
in fun postruns_add s f = 
       (log ("[postruns_add(" ^ s ^ ") begin]\n");
        postruns := f :: !postruns;
        log "[postruns_add end]\n")
        
   fun postruns_run () = 
       let val xs = !postruns
       in (log ("[running " ^ Int.toString(List.length xs) ^ " postruns begin]\n"); List.app (fn s => s()) xs; log "[running postruns end]\n")
       end
end

fun getElem id : Js.elem =
    case Js.getElementById Js.document id of
        SOME e => e
      | NONE => raise Fail "getElem"

(* User Code *)

val treedata = [
[("id","0"),("name","World"),("kind","folder")],
[("id","1"),("name","Europe"),("parent","0"),("kind","folder")],
[("id","2"),("name","Africa"),("parent","0")],
[("id","3"),("name","North America"),("parent","0"),("kind","folder")],
[("id","4"),("name","Germany"),("parent","1")],
[("id","5"),("name","Denmark"),("parent","1")],
[("id","6"),("name","Italy"),("parent","1")],
[("id","7"),("name","Norway"),("parent","1")],
[("id","8"),("name","Asia"),("parent","0")],
[("id","9"),("name","USA"),("parent","3")],
[("id","10"),("name","Canada"),("parent","3")],
[("id","11"),("name","Mexico"),("parent","3")]
]

val () = print "<link rel='stylesheet' href='dojo/resources/dojo.css'>"
(*
val () = print "<link rel='stylesheet' href='dgrid/css/dgrid.css'>"
val () = print "<link rel='stylesheet' href='dgrid/css/skins/claro.css'>"
val () = print "<link rel='stylesheet' href='dijit/themes/claro/claro.css'>"
*)
val () = print "<link rel='stylesheet' href='dojo-theme-flat/CSS/dojo/flat.css'>"
val () = print "<link rel='stylesheet' href='dojo-theme-flat/CSS/dgrid/css/dgrid.css'>"
val () = print "<link rel='stylesheet' href='dojo-theme-flat/CSS/dgrid/css/skins/skin.css'>"
           
(*
val () = print "<link rel='stylesheet' href='Esri-dojo-theme-flat-4e1fdb1/CSS/dojo/flat.css'>"
val () = print "<link rel='stylesheet' href='Esri-dojo-theme-flat-4e1fdb1/CSS/dgrid/css/dgrid.css'>"
val () = print "<link rel='stylesheet' href='Esri-dojo-theme-flat-4e1fdb1/CSS/dgrid/css/skins/skin.css'>"
*)               
val () = print "<link rel='stylesheet' href='mydojo.css'>"
val () = print "<body class='claro' id='body'></body>"

(* Filtering select data *)
val selectdata = ["Dog", "Horse", "Cat", "Mouse", "Cow", "Elephant", "Turtle", "Tiger", "Camel", "Sheep", "Deer", "Bat", "Catfish", "Donkey", "Duck", "Bear"]
val selectdata = List.rev(#2(List.foldl (fn (x,(i,a)) => (i+1,{id=Int.toString i,name=x}::a)) (0,nil) selectdata))

(* Grid widget *)

val gridData =
    [[("first","Hans"),("last","Eriksen"),("age", "45")],
     [("first","Grethe"),("last","Hansen"),("age", "25")],
     [("first","Jens"),("last","Ulrik"),("age", "8")]]

val gridM = 
    Grid.mk [("sort","last"),("className","dgrid-autoheight")] 
            [("first", "First Name"),
             ("last", "Last Name"),
             ("age", "Age")]

fun onClick w g (id,n) = (setContent w ("Got " ^ n ^ " - " ^ id);
                          Grid.add g gridData)


open Js.Element infix &

fun tag_sty t s e = taga t [("style",s)] e

fun mkFlexBox3 e1 e2 e3 =
    tag_sty "table" "width:100%;height:100%;border-spacing:0;border:none;" (
      tag "tr" (
        tag_sty "td" "width:50%;height:30px;padding:10px;text-align:left;" e1 &
        tag_sty "td" "width:50%;height:30px;padding:10px;text-align:right;" e2
      ) &
      tag_sty "tr" "height:100%;" (
        taga "td" [("colspan","2"),("style","width:100%;height:100%;")] e3
      )
    )

val outputElem = tag "div" ($"This is just an empty area, initially!")

fun button_handler theform username password age birthdate fselect () =
    if Form.validate theform then
      let val un = Editor.getValue username
          val pw = Editor.getValue password
          val age = Editor.getValue age
          val bd = case Editor.getValue birthdate of SOME s => "SOME(" ^ s ^ ")"
                                                   | NONE => "NONE"
          val animal = Editor.getValue fselect
      in Js.appendChild outputElem (tag "p" ($("{un=" ^ un ^ ",pw=" ^ pw ^ ",age=" ^ Int.toString age ^ ",birthdate=" ^ bd ^ ",animal=" ^ animal ^ "}")))
      end
    else Js.appendChild outputElem (tag "p" ($("Form not valid!")))

fun form theform username password age birthdate evennum fselect button tempc tempf tempk =
    let val e =
          tag "table" (
            tag "tr" (tag "td" ($"Username") & tag "td" (Editor.domNode username)) &
            tag "tr" (tag "td" ($"Password") & tag "td" (Editor.domNode password)) &
            tag "tr" (tag "td" ($"Age") & tag "td" (Editor.domNode age)) &
            tag "tr" (tag "td" ($"Birthdate") & tag "td" (Editor.domNode birthdate)) &
            tag "tr" (tag "td" ($"Evennum") & tag "td" (Editor.domNode evennum)) &
            tag "tr" (tag "td" ($"Favorite animal") & tag "td" (Editor.domNode fselect)) &
            tag "tr" (tag "td" ($"Temperature Celcius") & tag "td" (Editor.domNode tempc)) &
            tag "tr" (tag "td" ($"Temperature Fahrenheit") & tag "td" (Editor.domNode tempf)) &
            tag "tr" (tag "td" ($"Temperature Kelvin") & tag "td" (Editor.domNode tempk)) &
            tag "tr" (taga "td" [("align","center"),("colspan","2")] (Button.domNode button)))
        val f = Form.domNode theform
    in Js.appendChild f e;
       f
    end

fun parseEmail s = if s = "mael@diku.dk" then SOME s else NONE

fun restGrid addRow =
  let open RestGrid
      val colspecs = [hidden true (valueColspec {field="gid",label="gid",editor=NONE,typ=INT}),
                      hidden true (valuePrettyColspec {field="name",label="Name (with stuff)",editor=SOME(textBox[]),typ=STRING,pretty=fn s => $("name: " ^ s)}),
                      valueColspec {field="name",label="Name",editor=SOME(textBox[]),typ=STRING},
                      unhidable true (valueColspec {field="email",label="Email",editor=SOME(validationBox[]{fromString=parseEmail,toString=fn s => s}),typ=STRING}),
                      valueColspec {field="comments",label="Date",editor=SOME(dateBox[("style","width:150px;")]),typ=STRING},
                      actionColspec {label="Action",button={label="Print",icon=SOME EditorIcon.print},onclick=fn look => runDialog "Print" ($("Go to the printer... Pick up job " ^ 
                                                                                                                                              look "gid" ^ "..."))},
                      deleteColspec {label="Delete/Add",button={label="Delete",icon=SOME EditorIcon.delete}}]
      val target = "http://localhost:8080/rest/guests/"
      fun restrictFn g s = setCollection g {target=target ^ "?q(name)=" ^ s}
  in RestGrid.mk {target=target, headers=nil,idProperty="gid", addRow=addRow,notify=Notify.notify,notify_err=Notify.notify_err} colspecs >>= (fn rg =>
     (postruns_add "RestGrid.startup" (fn () => startup rg);
      (case addRow of
           NONE => RestGrid.setSummary rg [{field="name",elem= $"Summary"}]
         | _ => ());
      ret (domNode rg, restrictFn rg)))
  end

fun memGrid ms =
  let open RestGrid
      val colspecs = [valueColspec {field="name",label="Name",editor=NONE,typ=STRING},
                      valueColspec {field="age",label="Age",editor=NONE,typ=STRING},
                      actionColspec {label="Action",button={label="Print",icon=SOME EditorIcon.print},onclick=fn look => runDialog "Print" ($("Go to the printer... Pick up job " ^ 
                                                                                                                                              look "name" ^ "..."))}
                     ]
  in RestGrid.mkFromStore {store=ms,notify=Notify.notify,notify_err=Notify.notify_err} colspecs >>= (fn g =>
     (postruns_add "RestGrid.startup" (fn () => startup g);
      RestGrid.setSummary g [{field="name",elem= $"Summary"}];
      ret (domNode g)))
  end
      
fun panes g rg rg_ro n =
    if n = 0 then ret []
    else let val style = [("style","padding:0;border:0;margin:0;")]
             val (e,s) = case n of
                             2 => (rg,style) 
                           | 3 => let val (rg,restrictFn) = rg_ro
                                      val button = taga0 "input" [("type","button"),("value","Get the records with 'art' in the name!")]
                                      val () = Js.installEventHandler button Js.onclick (fn () => (restrictFn "%art%"; true))
                                      val e = mkFlexBox3 ($"The grid") button rg
                                  in (e,style) 
                                  end
                           | 1 => (g,style)
                           | _ => (Js.Element.$"",[])
         in pane (s@[("title", "Tab" ^ Int.toString n),EditorIcon.newPage]) e >>= (fn p =>
            panes g rg rg_ro (n-1) >>= (fn ps =>
            ret (p::ps)))
         end

fun validator s = case Int.fromString s of SOME i => if i mod 2 = 0 then SOME i else NONE
                                         | NONE => NONE

val uploadM =
    let fun onComplete (obj:foreignptr) =
            if JsCore.Object.get JsCore.string obj "status" = "ok" then
              runDialog "Upload success" ($"You have successfully uploaded your file.")
            else runDialog "Upload error" ($"Some error happened during upload...")
        fun onError uploader () =
            (UploadFile.reset uploader;
             runDialog "Upload error" ($"Some error happened during upload - maybe the file was too big or of the wrong type..."))
        fun uploadHandler uploader () =
          (UploadFile.upload uploader [("besked","hej")]) 
          handle _ => (UploadFile.reset uploader; runDialog "error" ($"Something went wrong"))
    in UploadFile.mk [("label","Pick a File"),("showInput","before")] {name="uploadfile", url="http://localhost:8080/uploadfile.sml",
                                                                       multiple=false,uploadOnSelect=false} >>= (fn uploader =>
       (UploadFile.onComplete uploader onComplete;
        UploadFile.onError uploader (onError uploader);
        Button.mk [("label","Upload")] (uploadHandler uploader) >>= (fn upload_btn =>
        ret(UploadFile.domNode uploader & Button.domNode upload_btn))))
    end

fun mkBox t e =
    pane [] e >>= (titlePane [("title",t)])

fun mkBoxNoTitle e =
    pane [] e >>= (titlePane [])
         
fun c2f v = 1.8 * v + 32.0
fun c2k v = v + 273.15

val m =
  Editor.mk (textBox []) >>= (fn username =>
  Editor.mk (textBox [("type","password")]) >>= (fn password =>
  Editor.mk (intBox []) >>= (fn age =>
  Editor.mk (realBox [] (StringCvt.FIX(SOME 2))) >>= (fn tempc =>
  Editor.mk (realBox [] (StringCvt.FIX(SOME 3))) >>= (fn tempf =>
  Editor.mk (realBox [] (StringCvt.FIX(SOME 4))) >>= (fn tempk =>
  Editor.mk (optionBox(dateBox [])) >>= (fn birthdate =>
  Editor.mk (validationBox [] {fromString=validator,toString=Int.toString}) >>= (fn evennum =>
  Editor.mk (filterSelectBox [("name","animal"),("searchAttr","name"),("value", "3"),("maxHeight","150")] true selectdata) >>= (fn fselect =>
 (Editor.onChange tempc (fn v => (Editor.setValue tempf (c2f v); Editor.setValue birthdate (SOME"1969-12-22")));
  Editor.onChange tempc (fn v => Editor.setValue tempk (c2k v));
  Editor.setReadOnly tempk true;
  Editor.setDisabled tempf true;
  postruns_add "Editor.startup" (fn() => Editor.startup fselect);
  Form.mk [] >>= (fn theform =>
  Button.mk [("label","Login")] (button_handler theform username password age birthdate fselect) >>= (fn button =>
  pane [("region", "top"),("style","height:30px;")] (tag "b" ($"Main Title")) >>= (fn toppane =>
  pane [("style","height:auto;")] outputElem >>= (fn botpane =>
  titlePane [("title","Output"),("region", "bottom"),
         ("splitter","true")] botpane >>= (fn botpane =>
  linkPane [("region", "right"), ("href","doc/ARRAY.sml.html"), ("style", "width:20%;"),
            ("splitter","true")] >>= (fn rightpane =>
  restGrid (SOME({label="Add",icon=SOME Icon.newTask},{label="Cancel",icon=SOME EditorIcon.cancel})) >>= (fn (rg,_) =>
  restGrid NONE >>= (fn rg_ro =>
  gridM >>= (fn g =>
  pane [("region","center"),("title", "First"),("closable","true"),("style","height:100%;"),EditorIcon.unlink] (Js.Element.$ "Initial value") >>= (fn p1 =>
  uploadM >>= (fn upload_elem =>
  pane [("title", "Second"),EditorIcon.save] (tag "h2" ($"A form") & form theform username password age birthdate evennum fselect button tempc tempf tempk &
                                              tag "h2" ($"Upload") & upload_elem) >>= (fn p2 =>
  pane [("title", "Grid"),("style","border:0;")] (Grid.domNode g) >>= (fn gridWidget =>
  treeStore treedata >>= (fn store =>
  tree [] "0" (onClick p1 g) store >>= (fn tr =>
  RestGrid.memoryStore {idProperty="name"} >>= (fn ms =>
  memGrid ms >>= (fn ge =>
 (RestGrid.memoryStoreAdd ms [[("name","Martin"),("age","46")],[("name","Sissel"),("age","43")]];
  panes ge rg rg_ro 4 >>= (fn ps =>
  accordionContainer [("title","Something"),("region","right"),
                      ("splitter","true")] ps >>= (fn ac =>
  mkBox "Box1" ($"Yes") >>= (fn b1 =>
  mkBox "Box2" ($"Yes") >>= (fn b2 =>
  mkBox "Box3" ($"Yes") >>= (fn b3 =>
  mkBoxNoTitle ($"Yes") >>= (fn b4 =>
  mkBox "Box5" ($"Yes") >>= (fn b5 =>
  tableContainer [("title","Tiles"),("cols","2"),("showLabels","false"),("spacing","5")] {showLabels=false} [b1,b2,b3,b4,b5] >>= (fn tableWidget =>
  pane [("title","The vissible strict tab-page")] ($"here we go...") >>= (fn strict =>
  let val lazy1 = pane [("title","Lazy1")] ($"Yes Madame")
      val lazy2 = pane [("title","Lazy2")] ($"Yes Sir")
  in
    lazyTabContainer [("title", "I'm Lazy")] (strict,[("Lazy1",SOME EditorIcon.print,lazy1),("Lazy2",NONE,lazy2)]) >>= (fn (lazyWidget,_) =>
    tabContainer [("region","center"),("tabPosition","bottom")] [p1,p2,gridWidget,ac,tableWidget,lazyWidget] >>= (fn tc =>
    borderContainer [("region","center"),
                     ("style", "height: 100%; width: 100%;")] [tc,botpane] >>= (fn ibc =>
    titlePane [("title","A Tree"),("region","left"),("splitter","true"),
               ("style","width:10%;")] tr >>= (fn tr =>
    borderContainer [("style", "height: 100%; width: 100%;")]
                    [tr,ibc,toppane,rightpane]
    ))))
  end)))))))))))))))))))))))))))))))))))))

fun setWindowOnload (f: unit -> unit) : unit =
    let open JsCore infix ==>
    in exec1{arg1=("a", unit ==> unit),
             stmt="return window.onload=a;",
             res=unit} f
    end

val () = setWindowOnload (fn () => (attachToElement (getElem "body") m (fn () => 
                                                                           (postruns_run();
                                                                            Js.appendChild (getElem "body") Notify.notifyAreaElem))))
end
