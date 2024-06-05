
structure Dojo :> DOJO = struct
  type icon = string * string
  type hash = (string * string) list
  type widget = foreignptr

  fun log s = JsCore.call1 ("console.log",JsCore.string,JsCore.unit) s

  val fptr2unit_T = JsCore.==>(JsCore.fptr,JsCore.unit)
  val unit2unit_T = JsCore.==>(JsCore.unit,JsCore.unit)

  infix >>=
  type 'a M = ('a -> unit) -> unit
  fun ret a f = f a
  fun (m : 'b M) >>= (k : 'b -> 'a M) : 'a M =
    fn c:'a -> unit => m(fn v:'b => k v c)

  fun mapM f nil = ret nil
    | mapM f (x::xs) = f x >>= (fn y => mapM f xs >>= (fn ys => ret(y::ys)))

  val require0 : unit M =
   fn (f:unit->unit) =>
      JsCore.exec1 {stmt="require(['dojo/domReady!'],f);",
                    arg1=("f",unit2unit_T),
                    res=JsCore.unit} f

  fun require1 (s:string) : foreignptr M =
      fn (f:foreignptr->unit) =>
         JsCore.exec2 {stmt="require([s,'dojo/domReady!'],f);",
                       arg1=("s",JsCore.string),
                       arg2=("f",fptr2unit_T),
                       res=JsCore.unit} (s,f)

  structure Promise : sig
    type 'a t
    val When  : 'a JsCore.T -> ('a t * ('a -> unit) -> unit) M
    val WhenE : 'a JsCore.T -> ('a t * ('a -> unit) * (string->unit) -> unit) M
  end = struct
    type 'a t = foreignptr
    fun When t =
      require1 "dojo/when" >>= (fn whenF =>
      ret (fn (promise,ok) =>
              JsCore.exec3 {arg1=("when",JsCore.fptr), arg2=("p",JsCore.fptr), arg3=("ok",JsCore.==>(t,JsCore.unit)), res=JsCore.unit, stmt="when(p,ok);"} (whenF,promise,ok)))
    fun WhenE t =
      require1 "dojo/when" >>= (fn whenF =>
      ret (fn (promise,ok,err) =>
              JsCore.exec4 {arg1=("when",JsCore.fptr), arg2=("p",JsCore.fptr),
                            arg3=("ok",JsCore.==>(t,JsCore.unit)),
                            arg4=("err",JsCore.==>(JsCore.string,JsCore.unit)),
                            res=JsCore.unit, stmt="when(p,ok,function(obj) { return err(JSON.parse(obj.response.data).error); });"} (whenF,promise,ok,err)))
  end

  fun domNode (c:widget) : Js.elem =
      Js.Element.fromForeignPtr(JsCore.getProperty c JsCore.fptr "domNode")

  fun startup (c:widget) : unit =
      JsCore.method0 JsCore.unit c "startup"

  fun run (m : unit M) : unit = m (fn x => x)

  local
        (* The dojo loading must be done at most once. If attachToElement is
           called twice before the boolean ref is updated, the loading
           could happen twice unless the code is protected with an
           execution thunk list. *)

        val thunks : (unit -> unit) list option ref = ref (SOME nil)

  in fun attachToElement (e: Js.elem) (m : widget M) (k:unit->unit): unit =   (* run *)
         let fun f() = require0(fn () => m(fn c => (Js.appendChild e (domNode c);
                                                    startup c;
                                                    k())))
         in case !thunks of
                SOME nil => (* first call *)
                (JsCore.exec0 {stmt="this.dojoConfig = {parseOnLoad: true};",
                               res=JsCore.unit} ();
                 thunks := SOME [f];
                 Js.loadScript "dojo/dojo.js" (fn () =>
                                                  let val fs = case !thunks of
                                                                   SOME fs => List.rev fs
                                                                 | NONE => raise Fail "impossible"
                                                  in thunks := NONE;
                                                     List.app (fn f => f()) fs
                                                  end))
              | SOME fs => (thunks := SOME(f::fs))   (* schedule the function for execution *)
              | NONE => f()  (* dojo has already been loaded *)
         end
  end

(* the old buggy code:

 fun attachToElement (e: Js.elem) (m : widget M) (k:unit->unit): unit =   (* run *)
         let val () = if !dojoLoaded then ()
                      else JsCore.exec0 {stmt="this.dojoConfig = {parseOnLoad: true};",
                                         res=JsCore.unit} ()
             fun exec() =
                 require0(fn () => m(fn c => (Js.appendChild e (domNode c);
                                              startup c;
                                              k())))
         in if !dojoLoaded then exec()
            else Js.loadScript "dojo/dojo.js" (fn () => (dojoLoaded := true; exec()))
         end
  end
*)

  fun addChild (e:widget) (p:widget) : unit =
      JsCore.method1 JsCore.fptr JsCore.unit e "addChild" p

  fun mkHash h = JsCore.Object.fromList JsCore.string h

  fun new0 c arg =
      let val obj = JsCore.exec2{stmt="return new c(h);", arg1=("c",JsCore.fptr), arg2=("h",JsCore.fptr),
                                 res=JsCore.fptr} (c,arg)
      in obj
      end

  fun new c h =
      new0 c (mkHash h)

  fun stackContainer (kind:string) (bh:(string*bool)list) (h:hash) (panes: widget list) : widget M =
      fn (f: widget -> unit) =>
         require1 kind
                  (fn Sc =>
                      let val h = mkHash h
                          val () = List.app (fn(k,v) => JsCore.Object.set JsCore.bool h k v) bh
                          val sc = new0 Sc(h)
                      in List.app (addChild sc) panes
                       ; f sc
                      end)

  val tabContainer = stackContainer "dijit/layout/TabContainer" []
  val borderContainer = stackContainer "dijit/layout/BorderContainer" []
  val layoutContainer = stackContainer "dijit/layout/LayoutContainer" []
  fun tableContainer h {showLabels} = stackContainer "dojox/layout/TableContainer" [("showLabels",showLabels)] h
  val accordionContainer = stackContainer "dijit/layout/AccordionContainer" []

  fun setContentElement w (e: Js.elem) =
    JsCore.exec2{stmt="w.set('content', e);",
                 arg1=("w",JsCore.fptr), arg2=("e",JsCore.fptr),
                 res=JsCore.unit} (w,Js.Element.toForeignPtr e)

  fun pane (h:hash) e : widget M =
      fn (f: widget -> unit) =>
         require1 "dijit/layout/ContentPane"
                  (fn Cp =>
                      let val p = new Cp(h)
                      in setContentElement p e
                       ; f p
                      end)

  fun dialog (h:hash) e : widget M =
      fn (f: widget -> unit) =>
         require1 "dijit/Dialog"
                  (fn D =>
                      let val d = new D(h)
                      in setContentElement d e
                       ; f d
                      end)

  fun showDialog d = JsCore.method0 JsCore.unit d "show"
  fun hideDialog d = JsCore.method0 JsCore.unit d "hide"
  fun resize d = JsCore.method0 JsCore.unit d "resize"
  fun refresh d = JsCore.method0 JsCore.unit d "refresh"

  fun runDialog title e =
      run (dialog[("title", title)] e >>= (ret o showDialog))

  fun titlePane (h:hash) (w: widget) : widget M =
      fn (f: widget -> unit) =>
         require1 "dijit/TitlePane"
                  (fn Tp =>
                      let val p = new Tp(h)
                          val () = addChild p w
                      in f p
                      end)

  fun linkPane (h:hash) : widget M =
      fn (f: widget -> unit) =>
         require1 "dijit/layout/LinkPane"
                  (fn Lp =>
                      let val p = new Lp(h)
                      in f p
                      end)

  fun setProp w t k v =
    JsCore.exec3{stmt="w.set(k,v);",
                 arg1=("w",JsCore.fptr),
                 arg2=("k",JsCore.string),
                 arg3=("v",t),
                 res=JsCore.unit} (w,k,v)

  fun setProperties h w =
      List.app (fn (k,v) => setProp w JsCore.string k v) h

  fun setBoolProperty (k,v) w =
      setProp w JsCore.bool k v

  fun setContent w s = setProp w JsCore.string "content" s

  fun selectChild w w2 = JsCore.method2 JsCore.fptr JsCore.bool JsCore.unit w "selectChild" w2 true
  fun removeChild w w2 = JsCore.method1 JsCore.fptr JsCore.unit w "removeChild" w2

  type treeStore = foreignptr
  fun treeStore (hs:hash list) : treeStore M =
      fn (f: treeStore -> unit) =>
         require1 "dojo/store/Memory" (fn Memory =>
         require1 "dojo/store/Observable" (fn Observable =>
                      let val data = JsCore.Array.fromList JsCore.fptr (List.map mkHash hs)
                          val h = JsCore.exec1{stmt="return {data:data,getChildren:function(obj) { return this.query({parent:obj.id}); }};",
                                               arg1=("data",JsCore.fptr),
                                               res=JsCore.fptr} data
                          val p = new0 Memory(h)
                          val p = JsCore.exec2{arg1=("Con",JsCore.fptr),
                                               arg2=("s",JsCore.fptr),
                                               res=JsCore.fptr,
                                               stmt="return new Con(s);"} (Observable,p)
                      in f p
                      end))

  fun treeStoreAdd ts h = JsCore.method1 JsCore.fptr JsCore.unit ts "add" (mkHash h)
  fun treeStoreRemove ts s = JsCore.method1 JsCore.string JsCore.unit ts "remove" s
  fun treeStoreClear (ts:treeStore) : unit =
      JsCore.exec1{arg1=("ts",JsCore.fptr),res=JsCore.unit,
                   stmt="ts.query().forEach(function(item){ts.remove(ts.getIdentity(item));});"} ts

  fun treeWidget (h: hash) {showRoot} rootId onClick (store:treeStore) : widget M =
      fn (f: widget -> unit) =>
         require1 "dijit/tree/ObjectStoreModel" (fn ObjectStoreModel =>
         require1 "dijit/Tree" (fn Tree =>
         let val modelArg =
                 JsCore.exec2{stmt="return {store:store,query:{id:id},mayHaveChildren:function(item){return item.kind == 'folder';}};",arg1=("store",JsCore.fptr),
                              arg2=("id",JsCore.string),res=JsCore.fptr}(store,rootId)
             val model = new0 ObjectStoreModel(modelArg)
             val treeArg = mkHash h
             val () = if showRoot then ()
                      else JsCore.Object.set JsCore.bool treeArg "showRoot" showRoot
             val () = JsCore.Object.set JsCore.fptr treeArg "model" model
             val () = JsCore.exec2{stmt="a.onClick = function(item) { f([item.id,item.name]); };",
                                   arg1=("a",JsCore.fptr), arg2=("f",JsCore.===>(JsCore.string,JsCore.string,
                                                                                 JsCore.unit)),
                                   res=JsCore.unit} (treeArg,onClick)
             val tree = new0 Tree(treeArg)
         in f tree
         end))

  fun tree h = treeWidget h {showRoot=true}

  type tabmap = widget * (string*widget)list ref
  fun advTabContainer (h:hash) : (tabmap * {select:string->unit,close:string->unit}) M =
      tabContainer h [] >>= (fn tabs =>
      let val tm = ref []
          fun withTab s f =
              case List.find (fn (s',_) => s=s') (!tm) of
                  SOME (_,p) => f p
                | NONE => ()
          fun select s = withTab s (selectChild tabs)
          fun close s =
              (withTab s (removeChild tabs);
               tm := List.filter (fn (s',_) => s<>s') (!tm))
      in ret ((tabs,tm), {select=select,close=close})
      end)

  fun set_onClose (w:widget) (f: unit -> bool) : unit =
      JsCore.exec2{stmt="w.onClose = f;",
                   arg1=("w",JsCore.fptr),
                   arg2=("f",JsCore.==>(JsCore.unit,JsCore.bool)),
                   res=JsCore.unit} (w,f)

  fun set_onShow (w:widget) (f: unit -> unit) : unit =
      JsCore.exec2{stmt="w.onShow = f;",
                   arg1=("w",JsCore.fptr),
                   arg2=("f",JsCore.==>(JsCore.unit,JsCore.unit)),
                   res=JsCore.unit} (w,f)

  fun runthemKeys nil = ret nil
    | runthemKeys ((k,x)::xs) = x >>= (fn x' => runthemKeys xs >>= (fn xs' => ret ((k,x')::xs')))

  fun appi f xs =
      let fun ai f i nil = ()
            | ai f i (x::xs) = (f(x,i);ai f (i+1) xs)
      in ai f 0 xs
      end

  fun lazyTabContainer (h:hash) (w,wMs) : (widget*{select:string->unit}) M =
      let val dummy_wMs = List.map (fn (title,icon,_) =>
                                        (title,
                                         pane ([("title",title),("style","margin:0;border:0;padding:0;")]@
                                             (case icon of SOME ic => [ic]
                                                         | NONE => [])) (Js.Element.$""))) wMs
          fun onShow w i bs () =
              let val r = List.nth (bs,i)
              in if !r then ()
                 else let val m =
                             #3 (List.nth (wMs,i)) >>= (fn wnew =>
                             (addChild w wnew;
                              r := true;
                              ret ()))
                      in run m
                      end
              end
          val bs = List.map (fn _ => ref false) wMs
          fun select tabs ws0 s =
              List.app (fn (k,w) => if k = s then selectChild tabs w else ()) ws0
      in runthemKeys dummy_wMs >>= (fn ws0 =>
         let val ws = List.map #2 ws0
         in tabContainer h (w::ws) >>= (fn tabs =>
            (appi (fn (w,i) => set_onShow w (onShow w i bs)) ws;
             ret (tabs,{select=select tabs ws0})))
         end)
      end

  structure Menu = struct
    type menu = foreignptr * bool
    fun mk h : (widget * menu) M =
      fn (f: widget * menu -> unit) =>
         require1 "dijit/MenuBar" (fn MenuBar =>
         let val menubar = new MenuBar(h)
         in f (menubar,(menubar,true))
         end)

    fun menu (m,_) s =
      fn (f: menu -> unit) =>
         require1 "dijit/PopupMenuBarItem" (fn PopupMenuBarItem =>
         require1 "dijit/DropDownMenu" (fn DropDownMenu =>
         let val dropdownmenu = new DropDownMenu([])
             val popupmenubaritem =
                 JsCore.exec3{arg1=("C",JsCore.fptr),
                              arg2=("s",JsCore.string),
                              arg3=("d",JsCore.fptr),
                              stmt="return new C({label: s, popup: d});",
                              res=JsCore.fptr} (PopupMenuBarItem, s, dropdownmenu)
             val () = addChild m popupmenubaritem
         in f (dropdownmenu, false)
         end))

    fun item (m,top) (s,i,onclick) : unit M =
        let val path = if top then "dijit/MenuBarItem" else "dijit/MenuItem"
        in fn (f : unit -> unit) =>
              require1 path (fn MenuItem =>
              let val h = [("label",s)]
                  val h = case i of SOME p => p :: h
                                  | NONE => h
                  val i = new MenuItem(h)
                  val () = JsCore.exec2{arg1=("i",JsCore.fptr),
                                        arg2=("f",JsCore.==>(JsCore.unit,JsCore.unit)),
                                        stmt="i.set('onClick', f);",
                                        res=JsCore.unit} (i,onclick)
              in addChild m i
               ; f()
              end)
        end
  end

  structure JsUtil = struct

    fun mk_con0 (con:string) (h:foreignptr) : foreignptr M =
      fn (k: foreignptr -> unit) => require1 con (fn F => k(new0 F h))

    fun mk_con (con:string) (h:hash) (r:bool) : foreignptr M =
        let val h = mkHash h
            val () = JsCore.Object.set JsCore.bool h "required" r
        in mk_con0 con h
        end

    fun get (p:string) (obj:foreignptr) : string =
        JsCore.exec2{arg1=("obj",JsCore.fptr),
                     arg2=("p",JsCore.string),
                     stmt="return obj.get(p);",
                     res=JsCore.string} (obj,p)
    fun set (p:string) (obj:foreignptr) (v:string) : unit =
        JsCore.exec3{arg1=("obj",JsCore.fptr),
                     arg2=("p",JsCore.string),
                     arg3=("v",JsCore.string),
                     stmt="obj.set(p,v);",
                     res=JsCore.unit} (obj,p,v)

    fun callFptrArr f xs =
        JsCore.exec2{arg1=("f",JsCore.fptr),arg2=("xs",JsCore.fptr),res=JsCore.fptr,
                     stmt="return f(xs);"} (f,JsCore.Array.fromList JsCore.fptr xs)

    fun on (t:'a JsCore.T) (obj:foreignptr) (event:string) (f: 'a -> unit) : unit =
         run(require1 "dojo/on" >>= (fn on =>
                       ret(JsCore.exec4{arg1=("on",JsCore.fptr),
                                        arg2=("obj",JsCore.fptr),
                                        arg3=("event",JsCore.string),
                                        arg4=("f",JsCore.==>(t,JsCore.unit)),
                                        res=JsCore.unit,
                                        stmt="on(obj,event,f);"} (on,obj,event,f))))
  end

  type editorOptions = {id:string,name:string}list

  type 'a editConArg = {hash:hash, required:bool, file:string,
                        fromString: string -> 'a option,
                        toString: 'a -> string,
                        editorOptions: editorOptions option,
                        autoComplete: bool}
  type 'a editor = foreignptr * 'a editConArg
  type 'a editCon = 'a editConArg * ('a editConArg -> 'a editor M)

  fun stringBox (file:string) (h:hash) : string editCon =
      ({hash=h,required=true,file=file,
        fromString=fn s => SOME s,
        toString=fn s => s,
        editorOptions=NONE,
        autoComplete=false},
       fn (a as {file=f,hash=h,required=r,...}) => JsUtil.mk_con f h r >>= (fn e => ret (e,a))
      )

  fun numFromString scan s =
      let val s = CharVector.map (fn #"-" => #"~" | c => c) s
          val ss = Substring.full s
      in case scan Substring.getc ss of
             SOME (v,ss) => if Substring.size ss = 0 then SOME v
                            else NONE

           | NONE => NONE
      end

  fun numToString tostring v =
      CharVector.map (fn #"~" => #"-" | c => c) (tostring v)

  val realFromString = numFromString Real.scan
  fun realToString rf = numToString (Real.fmt rf)
  val intFromString = numFromString (Int.scan StringCvt.DEC)
  val intToString = numToString Int.toString

(*  fun stringFromRealBox (file:string) (h:hash) : string editCon =
      ({hash=h,required=true,file=file,
        fromString=realFromString,
        toString=realToString},
       fn (a as {file=f,hash=h,required=r,...}) => JsUtil.mk_con f h r >>= (fn e => ret (e,a))
      )
*)

  fun textBox h : string editCon = stringBox "dijit/form/ValidationTextBox" h

(*
  fun numBox h : string editCon = stringFromRealBox "dijit/form/NumberTextBox" h
*)

  local
    fun isISO s =
        size s = 10 andalso String.sub(s,4) = #"-" andalso String.sub(s,4) = #"-" andalso
        List.all (fn i => Char.isDigit(String.sub(s,i))) [0,1,2,3,5,6,8,9]

    fun dateToISO (date : foreignptr) : string =
        let val formatarg = JsCore.Object.fromList JsCore.string [("selector","date"),("datePattern","yyyy-MM-dd")]
            val isostring = JsCore.call2 ("dojo.date.locale.format",JsCore.fptr,JsCore.fptr,JsCore.string) (date,formatarg)
        in isostring
        end

    fun localToISO s =
        let val parsearg = JsCore.Object.fromList JsCore.string [("selector","date")]
            val date = JsCore.call2 ("dojo.date.locale.parse",JsCore.string,JsCore.fptr,JsCore.fptr) (s,parsearg)
        in dateToISO date
        end

    fun toISO s =
        if isISO s then s
        else localToISO s
(*
        else let val s =
             in if size s > 10 then
                  let val s' = String.extract(s,0,SOME 10)
                  in if isISOdate s' then s'
                     else s
                  end
                else s
             end
*)

    fun isoFullToDate s =
        JsCore.exec1{arg1=("s",JsCore.string),res=JsCore.fptr,stmt="return new Date(Date.parse(s));"} s

    fun toString s =
        let val date = isoFullToDate s
        in dateToISO date
        end

    fun fromString s = SOME(toISO s)
  in

  val dateToISO : foreignptr -> string = dateToISO
  val isoFullToDate = isoFullToDate

  (* Notice that the intention is that, internally, all editors have
     values that are represented as strings. Thus the
     function toString should take a value and transform it into the
     internal string representation. Similarly, the function
     fromString should convert the internal representation into the
     external representation. With respect to the dateTextBox control,
     the internal representation, however, is *not* a string, thus, we
     need toString and fromString values that represent it in the internal representation *)

    fun dateBox h : string editCon =
        ({hash=h,required=true,file="dijit/form/DateTextBox",
          fromString=fromString,
          toString=toString,
          editorOptions=NONE,
          autoComplete=false},
         fn (a as {file=f,hash=h,required=r,...}) =>
            let val h = mkHash h
                val () = JsCore.Object.set JsCore.bool h "required" r
                val c = JsCore.Object.fromList JsCore.string [("datePattern", "yyyy-MM-dd")]
                val () = JsCore.Object.set JsCore.fptr h "constraints" c
            in JsUtil.mk_con0 f h >>= (fn e => ret (e,a))
            end
        )
  end

  fun orEmptyBox ({hash,file,fromString,toString,required,editorOptions,autoComplete},f) =
      ({hash=hash,required=false,file=file,
        fromString=fromString,toString=toString,editorOptions=editorOptions,
        autoComplete=autoComplete},f)

  fun isNull (s:string) : bool = JsCore.exec1{arg1=("s",JsCore.string),res=JsCore.bool,
                                              stmt="return (s==null);"} s

  fun isNullFptr (s:foreignptr) : bool = JsCore.exec1{arg1=("s",JsCore.fptr),res=JsCore.bool,
                                                      stmt="return (s==null);"} s

  fun optionBox ((a, mk): 'a editCon) : 'a option editCon =
      let fun transform ({hash,required= _, file,fromString:string -> 'a option,toString:'a -> string,
                          editorOptions,autoComplete}: 'a editConArg) : 'a option editConArg =
             {hash=hash,required=false,file=file,
              fromString=fn "" => SOME NONE | s => if isNull s then SOME NONE else SOME(fromString s),    (* : string -> 'a option option *)
              toString=fn NONE => "" | SOME s => toString s,         (* : 'a option -> string *)
              editorOptions=editorOptions,autoComplete=autoComplete}
          fun inverse ({hash,file,required= _,fromString:string-> 'a option option,toString: 'a option -> string,
                        editorOptions,autoComplete} : 'a option editConArg) : 'a editConArg =
             {hash=hash,file=file,required=false,
              fromString=fn s => case fromString s of SOME s => s
                                                    | NONE => NONE,
              toString=toString o SOME,
              editorOptions=editorOptions,
              autoComplete=autoComplete}
     in (transform a, fn x => (mk o inverse) x >>= (fn (e,a) => ret(e,transform a)))
     end

  fun mkEditorArgs ({hash, required, fromString:string-> 'a option, file, editorOptions, autoComplete, ...}: 'a editConArg) : foreignptr =
      let val h = mkHash hash
          val () = JsCore.Object.set JsCore.bool h "required" required
      in case file of
             "dijit/form/Select" =>
             let val options = JsCore.Array.empty()
                 val () = case editorOptions of
                              SOME data =>
                              List.app (fn {id,name} =>
                                           let val obj = JsCore.Object.empty()
                                               val () = JsCore.Object.set JsCore.string obj "label" id
                                               val () = JsCore.Object.set JsCore.string obj "value" name
                                               val _ = JsCore.Array.push JsCore.fptr options obj
                                           in ()
                                           end) data
                            | NONE => ()
                 val () = JsCore.Object.set JsCore.fptr h "options" options
             in h
             end
           | "dijit/form/FilteringSelect" =>
             (require1 "dojo/store/Memory" (fn Memory =>
              let val arr = JsCore.Array.empty()
                  val () = case editorOptions of
                               SOME data =>
                               List.app (fn {id,name} =>
                                            let val obj = JsCore.Object.empty()
                                                val () = JsCore.Object.set JsCore.string obj "id" id
                                                val () = JsCore.Object.set JsCore.string obj "name" name
                                                val _ = JsCore.Array.push JsCore.fptr arr obj
                                            in ()
                                            end) data
                             | NONE => ()
                  val dataObject = JsCore.Object.fromList JsCore.fptr [("data",arr)]
                  val store = new0 Memory dataObject
                  val () = JsCore.Object.set JsCore.bool h "autoComplete" autoComplete
                  val () = JsCore.Object.set JsCore.fptr h "store" store
              in ()
              end)
              ; h)
           | "dijit/form/DateTextBox" =>
             let val c = JsCore.Object.fromList JsCore.string [("datePattern", "yyyy-MM-dd")]
             in JsCore.Object.set JsCore.fptr h "constraints" c
              ; h
             end
           | _ =>
             let val fromString = if required then fn "" => NONE | s => fromString s
                                  else fromString
                 val () = JsCore.Object.set (JsCore.==>(JsCore.string,JsCore.bool)) h "validator"
                                            (fn s => case fromString s of SOME _ => true
                                                                        | NONE => false)
             in h
             end
      end

  fun validationBox h {fromString: string-> 'a option,toString: 'a -> string} : 'a editCon =
      ({hash=h,required=true,file="dijit/form/ValidationTextBox",
        fromString=fromString,toString=toString,editorOptions=NONE,autoComplete=false},
       fn arg => JsUtil.mk_con0 (#file arg) (mkEditorArgs arg) >>= (fn e => ret (e,arg))
      )

  fun intBox h : int editCon = validationBox h {fromString=intFromString,toString=intToString}
  fun realBox h rf : real editCon = validationBox h {fromString=realFromString,toString=realToString rf}

  fun selectBox (h:hash) (data:{id:string,name:string}list) : string editCon =
      ({hash=h,required=true,file="dijit/form/Select",fromString=fn s => SOME s, toString=fn s => s,
        editorOptions=SOME data,autoComplete=false},
       fn arg => JsUtil.mk_con0 (#file arg) (mkEditorArgs arg) >>= (fn e => ret (e,arg)))

  fun filterSelectBox (h:hash) autoComplete (data:{id:string,name:string}list) : string editCon =
      ({hash=h,required=true,file="dijit/form/FilteringSelect",fromString=fn s => SOME s, toString=fn s => s,
        editorOptions=SOME data,autoComplete=autoComplete},
       fn arg => JsUtil.mk_con0 (#file arg) (mkEditorArgs arg) >>= (fn e => ret (e,arg))
      )

  structure Editor = struct
    type 'a t = 'a editor
    fun mk (a,f) = f a

    local
      fun getDateVal (e:foreignptr) : string =
          let val obj = JsCore.Object.get JsCore.fptr e "value"
          in if isNullFptr obj then ""
             else dateToISO obj
          end
    in fun getValue ((e,a) : 'a t) =
           let val s = case #file a of
                           "dijit/form/DateTextBox" => getDateVal e
                         | _ => JsUtil.get "value" e
           in case #fromString a s of SOME v => v
                                    | NONE => raise Fail "Editor.getValue"
           end
       fun getValueOpt ((e,a): 'a t) =
           let val v = case #file a of
                        "dijit/form/DateTextBox" => getDateVal e
                        | _ => JsUtil.get "value" e
           in if isNull v then NONE else #fromString a v
           end
    end
    fun setNull (e:foreignptr) (k:string) : unit =
        JsCore.exec2{arg1=("obj",JsCore.fptr),arg2=("k",JsCore.string),res=JsCore.unit,
                     stmt="obj.set(k,null);"} (e,k)
    fun setValue ((e,a) : 'a t) v =
        let val s = #toString a v
        in case #file a of
               "dijit/form/DateTextBox" =>
               if s="" then setNull e "value"
               else JsCore.method2 JsCore.string JsCore.fptr JsCore.unit e "set" "value" (isoFullToDate s)
             | _ => JsUtil.set "value" e s
        end
    fun setDisabled ((e,a): 'a t) b = JsCore.method1 JsCore.bool JsCore.unit e "setDisabled" b
    fun setReadOnly ((e,a): 'a t) b = setBoolProperty ("readOnly",b) e
    fun onChange (e : 'a t) (f: 'a -> unit) : unit =
        let fun onChange0 (e,a) f = JsCore.method2 JsCore.string unit2unit_T JsCore.unit e "on" "change" f
        in onChange0 e (fn () => f (getValue e))
        end
    val domNode = fn ((e,_): 'a t) => domNode e
    fun toForeignPtr (x,_) = x
    val startup = fn (e,_) => startup e
  end

  structure Form = struct
    type t = foreignptr
    fun mk (h:hash) : t M =
        let val h = mkHash h
        in JsUtil.mk_con0 "dijit/form/Form" h
        end
    fun validate t = JsCore.method0 JsCore.bool t "validate"
    val domNode = domNode
    fun toForeignPtr x = x
    fun startup x = JsCore.method0 JsCore.unit x "connectChildren"
  end

  structure Button = struct
    type t = foreignptr
    fun mk (h:hash) (f:unit->unit) : t M =
        let val h = mkHash h
            val () = JsCore.exec2{arg1=("h",JsCore.fptr), arg2=("f",JsCore.==>(JsCore.unit,JsCore.unit)),
                                  res=JsCore.unit,stmt="h.onClick = f;"} (h,f)
        in JsUtil.mk_con0 "dijit/form/Button" h
        end
    val domNode = domNode
    fun toForeignPtr x = x
  end

  structure UploadFile = struct
    type t = foreignptr
    fun mk (h : hash) {url:string,multiple:bool,uploadOnSelect:bool,name:string} : t M =
        let val h = mkHash (("url",url)::("name",name)::h)
            val () = JsCore.Object.set JsCore.bool h "multiple" multiple
            val () = JsCore.Object.set JsCore.bool h "uploadOnSelect" uploadOnSelect
        in require1 "dojox/form/Uploader" >>= (fn Don'tUseThis =>
            let val uploader = JsCore.exec1 {arg1=("h",JsCore.fptr),res=JsCore.fptr,stmt="return new dojox.form.Uploader(h);"} h
            in ret uploader
            end)
        end
    fun upload (t:t) (h: hash) : unit =
        JsCore.method1 JsCore.fptr JsCore.unit t "upload" (mkHash h)

    fun reset (t:t) : unit =
        JsCore.method0 JsCore.unit t "reset"

    fun onComplete (obj:t) f = JsUtil.on JsCore.fptr obj "Complete" f
    fun onBegin (obj:t) f = JsUtil.on JsCore.unit obj "Begin" f
    fun onError (obj:t) f = JsUtil.on JsCore.unit obj "Error" f

    val domNode      : t -> Js.elem = domNode
    val toForeignPtr : t -> foreignptr = fn x => x
    val startup      : t -> unit = startup

  end

  structure RestGrid = struct
    type editspec = {hash:unit->foreignptr, file:string}
    fun editspec ((arg,_):'a editCon) : editspec =
        {hash=fn()=>mkEditorArgs arg,file= #file arg}

    type t = {elem: Js.elem, getStore: unit->foreignptr, startup: unit->unit, setStore: foreignptr -> unit,
              refresh: unit->unit, setCollection: string->unit, setSort: string->unit,
              setSummary : {field:string,elem:Js.elem}list -> unit}

    datatype typ = INT | STRING | NUM of int
    type button = {label:string,icon:icon option}
    datatype colspec = VALUE of {field:string,label:string,typ:typ,
                                 editor:editspec option,sortable:bool,prettyLook:((string->string)->Js.elem)option,hidden:bool,unhidable:bool}
                     | DELETE of {label:string,button:button,hidden:bool,unhidable:bool}
                     | ACTION of {label:string,onclick:(string->string)->unit,button:button,hidden:bool,unhidable:bool}
    fun valueColspec {field,label,editor,typ} =
        VALUE {field=field,label=label,
               editor=Option.map editspec editor,
               sortable=true,typ=typ,prettyLook=NONE,hidden=false,unhidable=false}
    fun valuePrettyColspec {field,label,editor,typ,pretty} =
        VALUE {field=field,label=label,editor=Option.map editspec editor,
               sortable=true,typ=typ,prettyLook=SOME (fn look => pretty(look field)),hidden=false,unhidable=false}
    fun valuePrettyLookColspec {field,label,editor,typ,pretty} =
        VALUE {field=field,label=label,editor=Option.map editspec editor,
               sortable=true,typ=typ,prettyLook=SOME pretty,hidden=false,unhidable=false}
    fun valuePrettyWithIdColspec {field,label,editor,typ,prettyWithId} =
        VALUE {field=field,label=label,editor=Option.map editspec editor,
               sortable=true,typ=typ,prettyLook=SOME (fn look => prettyWithId(look field,look "$pkey")),hidden=false,unhidable=false}
    fun deleteColspec {label:string,button:button} = DELETE {label=label,button=button,hidden=false,unhidable=false}
    fun actionColspec {label:string,button:button,onclick:(string->string)->unit} = ACTION {label=label,button=button,onclick=onclick,hidden=false,unhidable=false}

    fun sortable b (VALUE {field,label,typ,editor,sortable,prettyLook,hidden,unhidable}) =
        VALUE {field=field,label=label,typ=typ,editor=editor,sortable=b,prettyLook=prettyLook,hidden=hidden,unhidable=unhidable}
      | sortable b cs = cs

    fun hidden b (VALUE {field,label,typ,editor,sortable,prettyLook,hidden,unhidable}) =
        VALUE {field=field,label=label,typ=typ,editor=editor,sortable=sortable,prettyLook=prettyLook,hidden=b,unhidable=unhidable}
      | hidden b (DELETE {label,button,hidden,unhidable}) = DELETE {label=label,button=button,hidden=b,unhidable=unhidable}
      | hidden b (ACTION {label,onclick,button,hidden,unhidable}) = ACTION {label=label,onclick=onclick,button=button,hidden=b,unhidable=unhidable}

    fun unhidable b (VALUE {field,label,typ,editor,sortable,prettyLook,hidden,unhidable}) =
        VALUE {field=field,label=label,typ=typ,editor=editor,sortable=sortable,prettyLook=prettyLook,hidden=hidden,unhidable=b}
      | unhidable b (DELETE {label,button,hidden,unhidable}) = DELETE {label=label,button=button,hidden=hidden,unhidable=b}
      | unhidable b (ACTION {label,onclick,button,hidden,unhidable}) = ACTION {label=label,onclick=onclick,button=button,hidden=hidden,unhidable=b}

    fun setTypDefault typ obj f =
        case typ of
            INT => JsCore.Object.set JsCore.int obj f 0
          | STRING => JsCore.Object.set JsCore.string obj f ""
          | NUM _ => JsCore.Object.set JsCore.real obj f 0.0

    fun defaultsOfColspecs css =
        let val obj = JsCore.Object.empty()
            fun f (DELETE _) = ()
              | f (ACTION _) = ()
              | f (VALUE {field,typ,...}) = setTypDefault typ obj field
        in List.app f css; obj
        end

    fun member nil y = false
      | member (x::xs) y = x = y orelse member xs y

    fun fieldsOfColspecs css pkey =
        let val keys = List.foldr (fn (VALUE{field,...}, acc) => field::acc | (_,acc) => acc) nil css
        in if member keys pkey then keys
           else pkey::keys
        end

    fun setRenderCell h (f:unit -> Js.elem) : unit =
        let fun g() = Js.Element.toForeignPtr(f())
        in JsCore.Object.set (JsCore.==>(JsCore.unit,JsCore.fptr)) h "renderCell" g
        end

    fun setRenderCell1 h (f:foreignptr -> Js.elem) : unit =
        let val g = Js.Element.toForeignPtr o f
        in JsCore.Object.set (JsCore.==>(JsCore.fptr,JsCore.fptr)) h "renderCell" g
        end

    fun mkValueCol idProperty {editOn} {field,label,editor,sortable,typ,prettyLook,hidden,unhidable} =
        let val h = [("field",field),("label",label)]
            val h = mkHash h
            val () = JsCore.Object.set JsCore.bool h "sortable" sortable
            val () = JsCore.Object.set JsCore.bool h "hidden" hidden
            val () = JsCore.Object.set JsCore.bool h "unhidable" unhidable
            fun look p k =
                if k = "$pkey" then look p idProperty
                else JsCore.Object.get JsCore.string p k
            val () = case prettyLook of
                         NONE => ()
                       | SOME pp => setRenderCell1 h (pp o look)
        in case editor of
               NONE => ret h
             | SOME {hash=editorArgsFn,file} =>
               require1 file >>= (fn EditorCon =>
               (JsCore.Object.set JsCore.bool h "autoSave" true;
                (case editOn of
                     SOME value => JsCore.Object.set JsCore.string h "editOn" value
                   | NONE => ());
                JsCore.Object.set JsCore.fptr h "editor" EditorCon;
                JsCore.Object.set JsCore.fptr h "editorArgs" (editorArgsFn());
                ret h))
        end

    fun buttonArgs (button:button) =
        ([("label",#label button),("class","grid-button")] @
         (case #icon button of
              SOME i => [i]
            | NONE => []))

    fun mkGridCol _ Button idProperty fields getStore (VALUE valarg) =
        let val valarg = if idProperty = #field valarg then  (* don't allow editing of the primary key *)
                           {field= #field valarg, label= #label valarg, typ= #typ valarg,
                            editor=NONE,sortable= #sortable valarg, prettyLook= #prettyLook valarg, hidden= #hidden valarg, unhidable= #unhidable valarg}
                         else valarg
        in mkValueCol idProperty {editOn=SOME "dblclick"} valarg
        end
      | mkGridCol (notify,notify_err) Button idProperty fields getStore (DELETE {label,button,hidden,unhidable}) =
        Promise.WhenE JsCore.unit >>= (fn when =>
        let val h = [("field","delete"),("label",label)]
            val h = mkHash h
            val () = JsCore.Object.set JsCore.bool h "sortable" false
            val () = JsCore.Object.set JsCore.bool h "hidden" hidden
            val () = JsCore.Object.set JsCore.bool h "unhidable" unhidable
            val () = setRenderCell1 h (fn obj =>
                                           let val delbutton = new Button (buttonArgs button)
                                               val () = JsCore.Object.set unit2unit_T delbutton "onClick"
                                                   (fn () => let val id = JsCore.Object.get JsCore.int obj idProperty
                                                                 val store = getStore()
                                                                 val promise = JsCore.method1 JsCore.int JsCore.fptr store "remove" id
                                                             in when (promise, fn () => notify "Entry successfully deleted...", notify_err)
                                                             end)
                                           in domNode delbutton
                                           end)
        in ret h
        end)
      | mkGridCol _ Button idProperty fields getStore (ACTION {label:string,onclick:(string->string)->unit,button:button,hidden,unhidable}) =
        let val h = [("field","action"),("label",label)]
            val h = mkHash h
            val () = JsCore.Object.set JsCore.bool h "sortable" false
            val () = JsCore.Object.set JsCore.bool h "hidden" hidden
            val () = JsCore.Object.set JsCore.bool h "unhidable" unhidable
            val () = setRenderCell1 h (fn obj =>
                                           let val actionbutton = new Button (buttonArgs button)
                                               val () = JsCore.Object.set unit2unit_T actionbutton "onClick"
                                                   (fn () => let fun look k =
                                                                     if member fields k then JsCore.Object.get JsCore.string obj k
                                                                     else "not known"
                                                             in onclick look
                                                             end)
                                           in domNode actionbutton
                                           end)
        in ret h
        end

    fun mkColumns f colspecs =
        mapM f colspecs >>= (fn cols =>
        ret (JsCore.Array.fromList JsCore.fptr cols))

    fun mkRenderCol field label f =
        let val h = mkHash [("field",field),("label",label)]
            val () = JsCore.Object.set JsCore.bool h "sortable" false
            val () = setRenderCell h f
        in ret h
        end

    fun mkAddGridCol idProperty addbutton (VALUE{field,label,editor,typ,sortable,prettyLook,hidden,unhidable}) =
        if field <> idProperty then
          mkValueCol idProperty {editOn=NONE} {field=field,label=label,editor=editor,typ=typ,sortable=false,prettyLook=prettyLook,hidden=hidden,unhidable=unhidable}
        else mkRenderCol field label (fn () => Js.Element.$ "")
      | mkAddGridCol idProperty addbutton (ACTION {label,...}) = mkRenderCol "delete" label (fn () => Js.Element.$ "")
      | mkAddGridCol idProperty addbutton (DELETE {label,...}) = mkRenderCol "action" label (fn () => domNode addbutton)

    fun mkGrid GridCon {columns,collection} =
        let val arg = JsCore.Object.fromList JsCore.fptr [("columns",columns),
                                                          ("collection",collection)]
        in new0 GridCon(arg)
        end

    local open Js.Element infix &
    in fun tag_sty t s e = taga t [("style",s)] e
       fun mkFlexBox e1 e2 e3 =
        tag_sty "table" "width:100%;height:100%;border-spacing:0;border:none;" (
          tag "tr" (
            tag_sty "td" "width:100%;height:30px;padding:10px;text-align:right;" e1
          ) &
          tag "tr" (
            tag_sty "td" "width:100%;height:0px;" e2
          ) &
          tag_sty "tr" "height:100%;" (
            tag_sty "td" "width:100%;height:100%;" e3
          )
        )
    end

    fun set_showHeader g b =
        JsCore.method2 JsCore.string JsCore.bool JsCore.unit g "set" "showHeader" b
    fun set_label b l =
        JsCore.method2 JsCore.string JsCore.string JsCore.unit b "set" "label" l
    fun set_icon b NONE = ()
      | set_icon b (SOME(k,v)) = JsCore.method2 JsCore.string JsCore.string JsCore.unit b "set" k v

    fun mkHeaderArgs kvs =
        mkHash (List.map (fn (k,v) => ("SMLRest-" ^ k, v)) kvs)

    fun setSort grid field =
        JsCore.method2 JsCore.string JsCore.string JsCore.unit grid "set" "sort" field

    fun setSummary grid (cols:{field:string,elem:Js.elem}list) =
        let val summaryRow = JsCore.Object.empty()
        in List.app (fn {field,elem} => JsCore.Object.set JsCore.fptr summaryRow field (Js.Element.toForeignPtr elem)) cols
         ; JsCore.method2 JsCore.string JsCore.fptr JsCore.unit grid "set" "summary" summaryRow
        end

(*
    fun filterStore store (filter:(string*string)list) =
        let val filter = JsCore.Object.fromList JsCore.string filter
        in JsCore.method1 JsCore.fptr JsCore.fptr store "filter" filter
        end
*)
    fun mkSimple {target:string, headers, idProperty:string,notify,notify_err} (colspecs:colspec list) : t M =
        require1 "dojo/_base/declare" >>= (fn declare =>
        require1 "dgrid/OnDemandGrid" >>= (fn OnDemandGrid =>
        require1 "dgrid/Keyboard" >>= (fn Keyboard =>
        require1 "dgrid/Editor" >>= (fn Editor =>
        require1 "dstore/Rest" >>= (fn Rest =>
        require1 "dstore/Trackable" >>= (fn Trackable =>
        require1 "dstore/Memory" >>= (fn Memory =>
        require1 "dijit/form/Button" >>= (fn Button =>
        require1 "dgrid/extensions/ColumnHider" >>= (fn ColumnHider =>
        require1 "dgrid/extensions/ColumnResizer" >>= (fn ColumnResizer =>
        require1 "dgrid/extensions/DijitRegistry" >>= (fn DijitRegistry =>
        require1 "SummaryRow" >>= (fn SummaryRow =>
        let val RestTrackableStore = JsUtil.callFptrArr declare [Rest,Trackable]
            val MemoryTrackableStore = JsUtil.callFptrArr declare [Memory,Trackable]
            fun mkStore target =
                let val storeArg = mkHash [("target",target),("idProperty",idProperty)]
                    val () = if List.null headers then ()
                             else JsCore.Object.set JsCore.fptr storeArg "headers" (mkHeaderArgs headers)
                    val store = new0 RestTrackableStore(storeArg)
                in store
                end
            val store = mkStore target
            val storeRef = ref store
            fun getStore() = !storeRef
            val MyGrid = JsUtil.callFptrArr declare [OnDemandGrid,Keyboard,Editor,ColumnResizer,ColumnHider,DijitRegistry,SummaryRow]
            val fields = fieldsOfColspecs colspecs idProperty
        in mkColumns (mkGridCol (notify,notify_err) Button idProperty fields getStore) colspecs >>= (fn columns =>
        let val grid = mkGrid MyGrid {columns=columns,collection=store}
            fun start() = JsCore.method0 JsCore.unit grid "startup"
            open Js.Element infix &
            val gridelem = domNode grid
            val () = Js.setStyle gridelem ("height", "100%")
            val () = Js.setStyle gridelem ("width", "100%")
            fun refresh() = JsCore.method0 JsCore.unit grid "refresh"
            fun setCollection target =
                let val store = mkStore target
                    val () = storeRef := store
                    val () = JsCore.method2 JsCore.string JsCore.fptr JsCore.unit grid "set" "collection" store
                in refresh()
                end
        in ret {elem=gridelem,getStore=getStore,startup=start,refresh=refresh,setCollection=setCollection,
                setStore=fn _ => notify_err "setStore action not supported on simple grids (only on memory grids)",
                setSort=setSort grid,
                setSummary=setSummary grid}
        end)
        end))))))))))))

    fun mk {target:string, headers, idProperty:string, addRow=NONE, notify, notify_err} (colspecs:colspec list) : t M =
         mkSimple {target=target,headers=headers,idProperty=idProperty,notify=notify,notify_err=notify_err} colspecs
      | mk {target:string, headers, idProperty:string, addRow=SOME(butAdd,butCancel):(button*button) option,notify,notify_err} (colspecs:colspec list) : t M =
        require1 "dojo/_base/declare" >>= (fn declare =>
        require1 "dgrid/OnDemandGrid" >>= (fn OnDemandGrid =>
        require1 "dgrid/Keyboard" >>= (fn Keyboard =>
        require1 "dgrid/Editor" >>= (fn Editor =>
        require1 "dstore/Rest" >>= (fn Rest =>
        require1 "dstore/Trackable" >>= (fn Trackable =>
        require1 "dstore/Memory" >>= (fn Memory =>
        require1 "dijit/form/Button" >>= (fn Button =>
        require1 "dgrid/extensions/DijitRegistry" >>= (fn DijitRegistry =>
        require1 "SummaryRow" >>= (fn SummaryRow =>
        Promise.WhenE JsCore.unit >>= (fn when =>
        Form.mk [] >>= (fn form =>
        let
            val RestTrackableStore = JsUtil.callFptrArr declare [Rest,Trackable]
            val MemoryTrackableStore = JsUtil.callFptrArr declare [Memory,Trackable]
            val storeArg = mkHash [("target",target),("idProperty",idProperty)]
            val () = if List.null headers then ()
                     else JsCore.Object.set JsCore.fptr storeArg "headers" (mkHeaderArgs headers)
            val store = new0 RestTrackableStore(storeArg)
            fun getStore() = store
            val MyGrid = JsUtil.callFptrArr declare [OnDemandGrid,Keyboard,Editor,DijitRegistry,SummaryRow]
            val fields = fieldsOfColspecs colspecs idProperty
        in mkColumns (mkGridCol (notify,notify_err) Button idProperty fields getStore) colspecs >>= (fn columns =>
        let val grid = mkGrid MyGrid {columns=columns,collection=store}
            val button = new Button (buttonArgs butAdd)
            val addbutton = new Button (buttonArgs butAdd)
            fun sampleData () =
                let val h = defaultsOfColspecs colspecs
                    val () = JsCore.Object.set JsCore.int h idProperty 0
                in h
                end
            val addstore =
                let val arg = mkHash [("idProperty",idProperty)]
                    val () = JsCore.Object.set JsCore.fptr arg "data" (JsCore.Array.fromList JsCore.fptr [sampleData()])
                in new0 MemoryTrackableStore(arg)
                end
        in mkColumns (mkAddGridCol idProperty addbutton) colspecs >>= (fn addgridcolumns =>
        let val addgrid = mkGrid MyGrid {columns=addgridcolumns,collection=addstore}
            val addgridelem = domNode addgrid
            val addgridcontainer = Js.Element.taga "div" [("class","grid-add-row"),("style","width:100%;display:none;")] addgridelem
            fun clearAddGrid() =
                (JsCore.method1 JsCore.int JsCore.unit addstore "removeSync" 0;
                 JsCore.method1 JsCore.fptr JsCore.unit addstore "addSync" (sampleData());
                 JsCore.method0 JsCore.unit addgrid "refresh")
            fun start() =
                (JsCore.method0 JsCore.unit grid "startup";
                 JsCore.method0 JsCore.unit addgrid "startup";
                 clearAddGrid();
                 Form.startup form)

            fun addItemButtonToggle () =
                let val style = JsCore.Object.get JsCore.fptr (Js.Element.toForeignPtr addgridcontainer) "style"
                in if JsCore.Object.get JsCore.string style "display" = "block" then
                     (JsCore.Object.set JsCore.string style "display" "none";
                      Form.startup form;
                      set_label button (#label butAdd);
                      set_icon button (#icon butAdd);
                      set_showHeader grid true;
                      JsCore.method0 JsCore.unit grid "resize")
                   else
                     (JsCore.Object.set JsCore.string style "display" "block";
                      set_label button (#label butCancel);
                      set_icon button (#icon butCancel);
                      set_showHeader grid false;
                      JsCore.method0 JsCore.unit addgrid "refresh";
                      JsCore.method0 JsCore.unit addgrid "resize";
                      JsCore.method0 JsCore.unit grid "resize")
                end
            val () = JsCore.Object.set unit2unit_T addbutton "onClick"
                (fn () =>
                    (JsCore.method0 JsCore.unit addgrid "save";
                     if Form.validate form then
                       let val () = log "validate succeeded"
                           val data = JsCore.method1 JsCore.int JsCore.fptr addstore "getSync" 0
                           val obj = JsCore.Object.empty()
                           fun copyJs field t =
                               let val v = JsCore.Object.get t data field
                               in JsCore.Object.set t obj field v
                               end
                           fun copy f INT = copyJs f JsCore.int
                             | copy f STRING  = copyJs f JsCore.string
                             | copy f (NUM _)  = copyJs f JsCore.real
                           val () = List.app (fn DELETE _ => ()
                                               | ACTION _ => ()
                                               | VALUE{field,typ,...} => if field = idProperty then ()
                                                                         else copy field typ
                                             ) colspecs
                           val promise = JsCore.method1 JsCore.fptr JsCore.fptr store "put" obj
                       in when (promise, fn () =>
                                            (JsCore.method0 JsCore.unit grid "refresh";
                                             clearAddGrid();
                                             addItemButtonToggle();
                                             notify "Entry added successfully..."),
                               notify_err)
                       end
                     else ())
                )
            val () = JsCore.Object.set unit2unit_T button "onClick" addItemButtonToggle
            open Js.Element infix &
            val formelem = Form.domNode form
            val () = Js.appendChild formelem addgridcontainer
            val formcontainer = taga "table" [("style","width:100%;border-spacing:0;border:none;")] (tag "tr" (tag "td" formelem))
            val gridelem = domNode grid
            val () = Js.setStyle gridelem ("height", "100%")
            val () = Js.setStyle gridelem ("width", "100%")
            val () = Js.setStyle addgridelem ("width", "100%")
            val elem = mkFlexBox (domNode button) formcontainer gridelem
            fun refresh() = JsCore.method0 JsCore.unit grid "refresh"
        in ret {elem=elem,getStore=getStore,startup=start,refresh=refresh,
                setCollection=fn _ => notify_err "setCollection action not supported on advanced grids",
                setStore=fn _ => notify_err "setStore action not supported on advanced grids (only on memory grids)",
                setSort=setSort grid,
                setSummary=setSummary grid}
        end)
        end)
        end))))))))))))

    type s = foreignptr * string (* idProperty *)

    fun memoryStore {idProperty} : s M =
        require1 "dojo/_base/declare" >>= (fn declare =>
        require1 "dstore/Trackable" >>= (fn Trackable =>
        require1 "dstore/Memory" >>= (fn Memory =>
        let val MemoryTrackableStore = JsUtil.callFptrArr declare [Memory,Trackable]
            val storeArg = mkHash [("idProperty",idProperty)]
            val store = new0 MemoryTrackableStore(storeArg)
        in ret (store,idProperty)
        end)))

    fun memoryStoreAdd ((s,_):s) vs : unit =
        let fun addSync h : unit = JsCore.method1 JsCore.fptr JsCore.unit s "addSync" h
        in List.app (addSync o mkHash) vs
        end

    fun memoryStoreClear ((s,_):s) : unit =
        JsCore.exec1{arg1=("s",JsCore.fptr),res=JsCore.unit,
                     stmt="s.forEach(function(item){s.remove(s.getIdentity(item));});"} s

    fun mkFromStore {store=(store,idProperty),notify,notify_err} (colspecs:colspec list) : t M =
        require1 "dojo/_base/declare" >>= (fn declare =>
        require1 "dgrid/OnDemandGrid" >>= (fn OnDemandGrid =>
        require1 "dgrid/Keyboard" >>= (fn Keyboard =>
        require1 "dijit/form/Button" >>= (fn Button =>
        require1 "dgrid/extensions/ColumnHider" >>= (fn ColumnHider =>
        require1 "dgrid/extensions/ColumnResizer" >>= (fn ColumnResizer =>
        require1 "dgrid/extensions/DijitRegistry" >>= (fn DijitRegistry =>
        require1 "SummaryRow" >>= (fn SummaryRow =>
        let val storeRef = ref store
            fun getStore() = !storeRef
            val MyGrid = JsUtil.callFptrArr declare [OnDemandGrid,Keyboard,ColumnResizer,ColumnHider,DijitRegistry,SummaryRow]
            val fields = fieldsOfColspecs colspecs idProperty
        in mkColumns (mkGridCol (notify,notify_err) Button idProperty fields getStore) colspecs >>= (fn columns =>
        let val grid = mkGrid MyGrid {columns=columns,collection=store}
            fun start() = JsCore.method0 JsCore.unit grid "startup"
            open Js.Element infix &
            val gridelem = domNode grid
            val () = Js.setStyle gridelem ("height", "100%")
            val () = Js.setStyle gridelem ("width", "100%")
            fun refresh() = JsCore.method0 JsCore.unit grid "refresh"
            fun setCollection _ = raise Fail "Dojo.setCollection not supported for store-based grids"
            fun setStore grid store = JsCore.method2 JsCore.string JsCore.fptr JsCore.unit grid "set" "collection" store
        in ret {elem=gridelem,getStore=getStore,startup=start,refresh=refresh,setCollection=setCollection,
                setStore=setStore grid,
                setSort=setSort grid,
                setSummary=setSummary grid}
        end)
        end))))))))

    fun setMemoryStore (grid:t) ((store,_):s) : unit = #setStore grid store

    fun startup ({startup=start,...}: t) : unit = start()
    fun refresh ({refresh=refr,...}: t) : unit = refr()
    fun setCollection ({setCollection=set,...}:t) {target:string} : unit = set target
    fun setSort ({setSort=set,...}:t) {field:string} : unit = set field
    fun setSummary ({setSummary=set,...}:t) x : unit = set x

    val domNode : t -> Js.elem = fn {elem,...} => elem
    fun toStore ({getStore,...}: t) : foreignptr = getStore ()

  end

  structure Grid = struct
    type t = foreignptr
    fun mk h cols : t M =
      fn (f: t -> unit) =>
         require1 "dgrid/Grid" (fn Grid =>
         let val h = mkHash h
             val () = JsCore.Object.set JsCore.fptr h "columns" (mkHash cols)
             val grid = new0 Grid(h)
         in f grid
         end)
    fun add (g:t) (hs:hash list) : unit =
        let val hs = List.map mkHash hs
            val a = JsCore.Array.fromList JsCore.fptr hs
        in JsCore.method1 JsCore.fptr JsCore.unit g "renderArray" a
        end
    val domNode = domNode
    fun toForeignPtr x = x
  end

  structure Icon = struct
    fun wrap s = ("iconClass","dijitIcon dijitIcon" ^ s)
    val save = wrap "Save"
    val print = wrap "Print"
    val cut = wrap "Cut"
    val copy = wrap "Copy"
    val clear = wrap "Clear"
    val delete = wrap "Delete"
    val undo = wrap "Undo"
    val edit = wrap "Edit"
    val newTask = wrap "NewTask"
    val editTask = wrap "EditTask"
    val editProperty = wrap "EditProperty"
    val task = wrap "Task"
    val filter = wrap "Filter"
    val configure = wrap "Configure"
    val search = wrap "Search"
    val application = wrap "Application"
    val bookmark = wrap "Bookmark"
    val chart = wrap "Chart"
    val connector = wrap "Connector"
    val database = wrap "Database"
    val documents = wrap "Documents"
    val mail = wrap "Mail"
    val leaf = wrap "Leaf"
    val file = wrap "File"
    val function = wrap "Function"
    val key = wrap "Key"
    val package = wrap "Package"
    val sample = wrap "Sample"
    val table = wrap "Table"
    val users = wrap "Users"
    val folderClosed = wrap "FolderClosed"
    val folderOpen = wrap "FolderOpen"
    val error = wrap "Error"
  end

  structure EditorIcon = struct
  fun wrap s = ("iconClass","dijitEditorIcon dijitEditorIcon" ^ s)
  val sep = wrap "Sep"
  val save = wrap "Save"
  val print = wrap "Print"
  val cut = wrap "Cut"
  val copy = wrap "Copy"
  val paste = wrap "Paste"
  val delete = wrap "Delete"
  val cancel = wrap "Cancel"
  val undo = wrap "Undo"
  val redo = wrap "Redo"
  val selectAll = wrap "SelectAll"
  val bold = wrap "Bold"
  val italic = wrap "Italic"
  val underline = wrap "Underline"
  val strikethrough = wrap "Strikethrough"
  val superscript = wrap "Superscript"
  val subscript = wrap "Subscript"
  val justifyCenter = wrap "JustifyCenter"
  val justifyFull = wrap "JustifyFull"
  val justifyLeft = wrap "JustifyLeft"
  val justifyRight = wrap "JustifyRight"
  val indent = wrap "Indent"
  val outdent = wrap "Outdent"
  val listBulletIndent = wrap "ListBulletIndent"
  val listBulletOutdent = wrap "ListBulletOutdent"
  val listNumIndent = wrap "ListNumIndent"
  val listNumOutdent = wrap "ListNumOutdent"
  val tabIndent = wrap "TabIndent"
  val leftToRight = wrap "LeftToRight"
  val rightToLeft = wrap "RightToLeft"
  val toggleDir = wrap "ToggleDir"
  val backColor = wrap "BackColor"
  val foreColor = wrap "ForeColor"
  val hiliteColor = wrap "HiliteColor"
  val newPage = wrap "NewPage"
  val insertImage = wrap "InsertImage"
  val insertTable = wrap "InsertTable"
  val space = wrap "Space"
  val insertHorizontalRule = wrap "InsertHorizontalRule"
  val insertOrderedList = wrap "InsertOrderedList"
  val insertUnorderedList = wrap "InsertUnorderedList"
  val createLink = wrap "CreateLink"
  val unlink = wrap "Unlink"
  val viewSource = wrap "ViewSource"
  val removeFormat = wrap "RemoveFormat"
  val fullScreen = wrap "FullScreen"
  val wikiword = wrap "Wikiword"
  end
end
