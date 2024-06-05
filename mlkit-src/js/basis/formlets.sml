(* Copyright 2015, Martin Elsman, MIT-license *)

structure Formlets :> FORMLETS = struct
  type key = string
  type label = string
  type value = string

  (* Some utilities *)
  fun qq s = "'" ^ s ^ "'"
  fun die s = raise Fail ("Formlets die: " ^ s)
  fun removeChildren elem =
      case Js.firstChild elem of
          SOME c => (Js.removeChild elem c; removeChildren elem)
        | NONE => ()

  open Js.Element infix &

  (* Elements *)
  type hidden = {value:string ref,listeners:(string -> unit)list ref}
  datatype elem = EDITCON of string Dojo.editCon * string | BUTTON | HIDDEN of hidden
  type el = {elem:elem,key:string,label:string,id:int}

  val newId : unit -> int =
      let val c = ref 0
      in fn () => !c before c:= !c + 1
      end
      
  fun fromEditCon (ec: string Dojo.editCon) : el = {elem=EDITCON(ec,""),key="",label="",id=newId()}
  val textbox : unit -> el = fn () => fromEditCon (Dojo.textBox[])
  val intbox  : unit -> el = fn () => fromEditCon (Dojo.textBox[])
  val realbox : unit -> el = fn () => fromEditCon (Dojo.textBox[])
  val datebox : unit -> el = fn () => fromEditCon (Dojo.textBox[])
  fun selectbox sls : el = fromEditCon (Dojo.filterSelectBox[] true (List.map (fn (k,v) => {id=k,name=v}) sls))
  val boolbox : unit -> el = fn () => selectbox [("true","True"),("false","False")]
  val hidden : unit -> el = fn () => {elem=HIDDEN {value=ref "",listeners=ref nil},key="",label="",id=newId()}

  fun withKey (e:el,k) : el = 
      if #key e = "" then {elem= #elem e,label= #label e,key=k,id= #id e}
      else die ("Cannot set key " ^ qq k ^ " for an element that already has the key " ^ qq(#key e))

  fun withLabel (e:el,l) : el = {elem= #elem e,label=l,key= #key e,id= #id e}

  fun wValue (EDITCON(ec,_),v) = EDITCON(ec,v)
    | wValue (HIDDEN vl,v) = (#value vl := v; HIDDEN vl)
    | wValue _ = die "wValue.button"

  fun withValue (e:el,v) : el = {elem= wValue(#elem e,v),label= #label e,key= #key e,id= #id e}

  type button = el
  val button : label -> el = fn label => {elem=BUTTON,key="",label=label,id=newId()}

  (* Forms *)
  type span = int
  datatype form = Lf of el * span                       (* Leaf *)
                | Vf of form list                       (* Vertical *)
                | Hf of form list                       (* Horizontal *)
                | Gf of label * form * span             (* Group with label *)
                | Ef                                    (* Empty (identity for >> and />) *)
                | Elf of label option * Js.elem * span  (* Dom element with optional label *)
                | Cf of el * (string*form)list * span   (* Changer *)

  val % : el -> form = fn x => Lf (x,1)
  val %% : button -> form = %

  fun hextend (Lf (x,s)) = Lf (x,s+1)
    | hextend (Vf xs) = Vf (List.map hextend xs)
    | hextend (Hf xs) = (case rev xs of
                             nil => Ef
                           | x::xs => Hf (rev(hextend x :: xs)))
    | hextend (Gf (x,y,s)) = Gf(x,y,s+1)
    | hextend Ef = Ef
    | hextend (Elf(lopt,x,s)) = Elf(lopt,x,s+1)
    | hextend (Cf(x,y,s)) = Cf(x,y,s+1)

  fun op >> (Ef,f) = f
    | op >> (f,Ef) = f
    | op >> (Hf fs1, Hf fs2) = Hf(fs1@fs2)
    | op >> (Hf fs1, f) = Hf(fs1@[f])
    | op >> (f,Hf fs2) = Hf(f::fs2)
    | op >> (f1,f2) = Hf[f1,f2]

  fun op /> (Ef,f) = f
    | op /> (f,Ef) = f
    | op /> (Vf fs1, Vf fs2) = Vf(fs1@fs2)
    | op /> (Vf fs1, f) = Vf(fs1@[f])
    | op /> (f,Vf fs2) = Vf(f::fs2)
    | op /> (f1,f2) = Vf[f1,f2]

  val group     : label -> form -> form = fn l => fn f => Gf(l,f,1)
  val empty     : form = Ef
  val changer   : el -> (string * form) list -> form = fn el => fn sfs => Cf(el,sfs,1)
  val space     : form = Elf(NONE,$"",1)
  val elem      : string option -> Js.elem -> form = fn lopt => fn x => Elf(lopt,x,1)

  (* Fields *)
  datatype f0 = value0 of el | readonly0 of el | enabled0 of el | pair0 of f0 * f0 | emp0
  datatype gen = Sgen of string | Ugen | Pgen of gen * gen | Bgen of bool
  fun unPgen (Pgen (g1,g2)) = (g1,g2)
    | unPgen _ = die "unPgen"
  fun unSgen (Sgen s) = s
    | unSgen _ = die "unSgen"
  fun unBgen (Bgen b) = b
    | unBgen _ = die "unBgen"
  type 'a f = f0 * ('a -> gen) * (gen -> 'a)

  fun value e0 = (value0 e0,Sgen,unSgen)
  fun readonly e0 = (readonly0 e0,Bgen,unBgen)
  fun enabled e0 = (enabled0 e0,Bgen,unBgen)
  fun || ((f01,to1,from1),(f02,to2,from2)) = (pair0(f01,f02), fn(x,y)=>Pgen(to1 x,to2 y), fn g => let val (x,y) = unPgen g in (from1 x, from2 y) end)
  val emp = (emp0,fn () => Ugen, fn Ugen => () | _ => die "unUgen")
  fun && (x,y) = (x,y)

  (* Rules *)
  exception AbortRule
  exception FormletError of string
  datatype rule = Init_rule of f0 * (unit -> gen) | Update_rule of el option * f0 * f0 * (gen -> gen) | Submit_rule of el * ((key*value option)list -> unit) | Load_rule of unit -> (key*value)list
                | PostUpdate_rule of f0 * f0 * (gen -> gen) | All_rule of rule list
  val all_rule = All_rule
  fun init_rule (f : 'a f) (g: unit -> 'a) : rule = Init_rule (#1 f, #2 f o g)
  fun load_rule f : rule = Load_rule f
  fun update_rule (f1: 'a f) (f2: 'b f) (g: 'a -> 'b) : rule = Update_rule (NONE, #1 f1, #1 f2, #2 f2 o g o #3 f1)
  fun postupdate_rule (f1: 'a f) (f2: 'b f) (g: 'a -> 'b) : rule = PostUpdate_rule (#1 f1, #1 f2, #2 f2 o g o #3 f1)
  fun button_rule (e:el) (f1: 'a f) (f2: 'b f) (g: 'a -> 'b) : rule = Update_rule (SOME e, #1 f1, #1 f2, #2 f2 o g o #3 f1)
  fun validate_rule (f:'a f) (g: 'a -> string option) : rule =
      update_rule f emp (fn x => case g x of NONE => () 
                                           | SOME s => raise FormletError s)
  fun submit_rule (e:el) f = Submit_rule(e,f)
 
  (* Interpretation *)
  val ret = Dojo.ret
  val >>= = Dojo.>>= infix >>=
  type 'a M = 'a Dojo.M
  type formlet = form * rule list

  fun tag_sty t s e = taga t [("style",s)] e

  fun boxGroup span lab e =
    Dojo.pane [("style","height:auto;width:100%;")] e >>= (fn p =>
    Dojo.titlePane [("title",lab)] p >>= (fn w => 
    (Dojo.setBoolProperty ("toggleable", false) w;
     let val attr = [("style","vertical-align:top;")]
         val attr = if span = 1 then attr else ("colspan",Int.toString span)::attr
         val parent = taga0 "td" attr
     in Dojo.attachToElement parent (Dojo.ret w) (fn () => ())
      ; Dojo.ret parent
     end)))

  datatype key_thing = ED of string Dojo.Editor.t 
                     | BUT of Dojo.Button.t * ((unit->unit)->unit) 
                     | HID of hidden

  (* Assumptions:
    1. No duplicate use of elements
    2. No duplicate use of keys
  *)

  fun spantd 1 e = taga "td" [("style","vertical-align:top;")] e
    | spantd n e = taga "td" [("colspan",Int.toString n),("style","vertical-align:top;")] e

  fun mkForm form : ((int*key*key_thing)list * Js.elem) M =         (* invariant: returns a list of key mappings and an element representing row content *)
      case form of
          Lf ({elem=BUTTON,key,label,id},span) =>
          let val listeners : (unit->unit) list ref = ref nil
              fun onclick () = List.app (fn f => f()) (!listeners)
              fun attachOnclick f = listeners := (f :: !listeners)
          in Dojo.Button.mk [("label",label)] onclick >>= (fn but =>
             let val e = Dojo.Button.domNode but
             in ret ([(id,key,BUT(but,attachOnclick))],spantd span e)
             end)
          end
        | Lf ({elem=EDITCON (ec,v),key,label,id},span) =>
          Dojo.Editor.mk ec >>= (fn ed =>
          let val e = spantd span (Dojo.Editor.domNode ed)
              val e = if label <> "" then taga "td" [("class","formlets-label-td")] ($label) & e else e
          in (if v<>"" then Dojo.Editor.setValue ed v else ());
             ret ([(id,key,ED ed)], e)
          end)
        | Lf ({elem=HIDDEN vl,key,label,id},_) => ret ([(id,key,HID vl)], $"")
        | Vf forms => 
          mkForms forms >>= (fn (kvs,es) =>
          let val trs = List.foldr (fn (e,a) => tag "tr" e & a) ($"") es
          in ret(kvs, taga "td" [("style","vertical-align:top;")] (taga "table" [("style","width:100%;")] trs))
          end)
        | Hf forms => 
          mkForms forms >>= (fn (kvs,es) =>
          let val e = List.foldr (fn (e,a) => e & a) ($"") es
          in ret(kvs, e)
          end)
        | Gf (lab,form,span) =>
          mkForm form >>= (fn (kvs,e) => 
          boxGroup span lab (taga "table" [("style","width:100%;")] (tag "tr" e)) >>= (fn e =>
          ret (kvs,e)))
        | Ef => ret (nil, $"")
        | Elf (NONE,e,span) => ret (nil, spantd span e)
        | Elf (SOME lab,e,span) => ret (nil, taga "td" [("class","formlets-label-td")] ($lab) & spantd span e)
        | Cf ({elem=HIDDEN vl,key,id,...},sfs,span) =>
          mkKeyForms sfs >>= (fn (kvs,ses) =>
          case ses of
              (s,e)::_ => 
              let fun find nil _ = NONE
                    | find ((k,v)::kvs) s = if k=s then SOME v else find kvs s 
                  val e = case !(#value vl) of
                              "" => (#value vl := s; e)
                            | k => case find ses k of
                                       SOME e => e
                                     | NONE => (#value vl := s; e)
                  val e0 = tag "tr" e
                  val t = taga "table" [("style","width:100%;border-spacing:0;border:none;")] e0
                  fun onChange s =
                      case find ses s of
                          SOME e => (removeChildren e0;
                                     Js.appendChild e0 e)
                        | NONE => die ("changer: cannot find element for " ^ s)
                  fun look nil = false
                    | look ((id0,_,_)::rest) = id = id0 orelse look rest
                  val kvs = if look kvs then kvs else (id,key,HID vl)::kvs
              in #listeners vl := onChange :: (!(#listeners vl))
               ; ret (kvs,spantd span t)
              end
            | _ => die "Changer requires at least one possibility"
          )
        | Cf _ => die "Changer requires hidden field"

  and mkForms nil : ((int*key*key_thing)list * Js.elem list) M = ret (nil,nil)
    | mkForms (form::forms) = mkForm form >>= (fn (kvs1,e) =>
                              mkForms forms >>= (fn (kvs2,es) => ret (kvs1@kvs2,e::es)))
  and mkKeyForms nil : ((int*key*key_thing)list * (string*Js.elem) list) M = ret (nil,nil)
    | mkKeyForms ((s,form)::forms) = mkForm form >>= (fn (kvs1,e) =>
                                     mkKeyForms forms >>= (fn (kvs2,es) => ret (kvs1@kvs2,(s,e)::es)))

  structure Rules = struct
    fun lookup nil id = NONE
      | lookup ((id0,_,ed)::rest) id = if id=id0 then SOME ed else lookup rest id

    fun lookup_key nil key = NONE
      | lookup_key ((_,k,ed)::rest) key = if k=key then SOME ed else lookup_key rest key

    fun upd_key kvs (k,v) =
        case lookup_key kvs k of
            SOME (ED ed) => Dojo.Editor.setValue ed v
          | SOME (HID vl) => #value vl := v
          | SOME (BUT _) => die ("upd_key.does not expect button for key " ^ qq k)
          | NONE => die ("upd_key.no editor for key " ^ qq k)

    fun upd kvs f0 g =
        case f0 of
            value0 {id,key,...} =>
            (case lookup kvs id of
                 SOME (ED ed) => Dojo.Editor.setValue ed (unSgen g)
               | SOME (HID vl) =>
                 let val s = unSgen g
                 in #value vl := s
                  ; List.app (fn f => f s) (!(#listeners vl))
                 end
               | SOME (BUT _) => die "Rules.upd.button"
               | NONE => die ("Rules.upd.value: id " ^ Int.toString id ^ " (" ^ key ^ ") not present in form"))
          | readonly0 {id,key,...} =>
            (case lookup kvs id of
                 SOME (ED ed) => Dojo.Editor.setReadOnly ed (unBgen g)
               | SOME (HID _) => die "Rules.upd.readonly.hidden"
               | SOME (BUT _) => die "Rules.upd.readonly.button"
               | NONE => die ("Rules.upd.readonly: id " ^ Int.toString id ^ " (" ^ key ^ ") not present in form"))
          | enabled0 {id,key,...} =>
            (case lookup kvs id of
                 SOME (ED ed) => Dojo.Editor.setDisabled ed (not(unBgen g))
               | SOME (HID _) => die "Rules.upd.enabled.hidden"
               | SOME (BUT _) => die "Rules.upd.enabled.button"
               | NONE => die ("Rules.upd.enabled." ^ Int.toString id ^ " (" ^ key ^ ") not present in form"))
          | emp0 => ()
          | pair0 (f01,f02) => 
            let val (g1,g2) = unPgen g
            in upd kvs f01 g1;
               upd kvs f02 g2
            end
                
    fun get kvs f0 : gen =
        case f0 of
            value0 {id,...} =>
            (case lookup kvs id of
                 SOME (ED ed) => Sgen(Dojo.Editor.getValue ed)
               | SOME (HID vl) => Sgen(!(#value vl))
               | SOME (BUT _) => die "Rules.get.button"
               | NONE => die ("Rules.get." ^ Int.toString id))
          | readonly0 {id,...} => die "Rules.get.readonly not implemented"
          | enabled0 {id,...} => die "Rules.get.enabled not implemented"
          | emp0 => Ugen
          | pair0 (f01,f02) => Pgen(get kvs f01, get kvs f02)

    fun inst kvs f0 f : unit =
        case f0 of
            value0 {id,...} =>
            (case lookup kvs id of
                 SOME (ED ed) => Dojo.Editor.onChange ed (fn _ => f())
               | SOME (HID vl) => (#listeners vl) := (fn _ => f()) :: (!(#listeners vl))
               | SOME (BUT _) => die "Rules.inst.button"
               | NONE => die ("Rules.inst." ^ Int.toString id))
          | readonly0 {id,...} => die "Rules.inst.readonly not implemented"
          | enabled0 {id,...} => die "Rules.inst.enabled not implemented"
          | emp0 => ()
          | pair0 (f01,f02) => (inst kvs f01 f; inst kvs f02 f)

    fun getValues kvs =
        List.foldl (fn ((_,"",_),a) => a
                     | ((_,_,BUT _),a) => a
                     | ((_,k,ED ed),a) => (k,Dojo.Editor.getValueOpt ed)::a
                     | ((_,k,HID vl),a) => (k, SOME(!(#value vl)))::a) nil kvs

    fun mkOnChange error_reporter kvs f01 f02 f () =
        case SOME (get kvs f01) handle _ => NONE of
            SOME vs => (upd kvs f02 (f vs)
                        handle AbortRule => ()
                             | FormletError s => (error_reporter s; raise Fail "formlet error"))
          | NONE => ()

    fun setupRule error_reporter dojo_form kvs r =
        case r of
            Init_rule (f0,f:unit -> gen) => (upd kvs f0 (f()) handle AbortRule => ())
          | Update_rule (NONE,f01,f02,f) => inst kvs f01 (mkOnChange error_reporter kvs f01 f02 f)
          | PostUpdate_rule (f01,f02,f) => ()
          | Update_rule (SOME {id,...},f01,f02,f) =>
            (case lookup kvs id of
                 SOME (BUT (_,attachOnClick)) => attachOnClick (mkOnChange error_reporter kvs f01 f02 f)
               | SOME (HID _) => die ("Rules.setupRule.expecting button - got hidden for " ^ Int.toString id)
               | SOME (ED ed) => die ("Rules.setupRule.expecting button - got ed for " ^ Int.toString id)
               | NONE => die ("Rules.setupRule.expecting button - got nothing for " ^ Int.toString id))
          | Submit_rule ({id,...},f) => 
            (case lookup kvs id of
                 SOME (BUT (_,attachOnClick)) => attachOnClick (fn () => if Dojo.Form.validate dojo_form then (f(getValues kvs); Dojo.Form.startup dojo_form)
                                                                         else f nil)
               | SOME (HID _) => die ("Rules.setupRule.submit.expecting button - got hidden for " ^ Int.toString id)
               | SOME (ED ed) => die ("Rules.setupRule.submit.expecting button - got ed for " ^ Int.toString id)
               | NONE => die ("Rules.setupRule.submit.expecting button - got nothing for " ^ Int.toString id))
          | Load_rule f => List.app (upd_key kvs) (f())
          | All_rule rs => List.app (setupRule error_reporter dojo_form kvs) rs

    fun setupPostRule guard error_reporter kvs r =
        case r of
            Init_rule _ => ()
          | Update_rule _ => ()
          | PostUpdate_rule (f01,f02,f) =>
            let fun onchange () =
                    if !guard then ()
                    else upd kvs f02 (f(get kvs f01))
                         handle AbortRule => ()
                              | FormletError s => (error_reporter s; raise Fail "formlet error")
            in inst kvs f01 onchange
            end
          | Submit_rule ({id,...},f) => ()
          | Load_rule f => ()
          | All_rule rs => List.app (setupPostRule guard error_reporter kvs) rs
  end                                                      

  type error_reporter = string -> unit

  (* At formlet construction time, we should check, early, for a number of properties:
       1. no cycles in update rule graph
       2. no cycles in button rules (why is this a problem?)
       3. all rule field ids are present in the form
       4. no element key is overwritten (done)
       5. an element key is defined at most once
       6. elements (their ids) are used at most once in a form
  *)
  fun mk (form,rules) error_reporter : ((unit->unit) * Dojo.widget) M =
      mkForm form >>= (fn (kvs,e) =>
      Dojo.Form.mk[] >>= (fn dojo_form =>
      let val form_elem = Dojo.Form.domNode dojo_form
          val () = Js.appendChild form_elem (taga "table" [("style","width:100%;")] (tag "tr" e))
          val guard = ref true
          fun startup () =
              (List.app (fn (_,_,ED ed) => Dojo.Editor.startup ed
                        | _ => ()) kvs;
               Dojo.Form.startup dojo_form; 
               List.app (Rules.setupPostRule guard error_reporter kvs) rules;
               guard := false;
               Js.setStyle form_elem ("height","auto;"))
      in Dojo.pane [("style","height:100%;overflow:auto;")] form_elem >>= (fn w =>
         (List.app (Rules.setupRule error_reporter dojo_form kvs) rules;
          ret (startup,w)))
      end))

  fun install (e: Js.elem) formlet error_reporter : unit =
      let val startupRef = ref (fn()=>())
          val wM = mk formlet error_reporter >>= (fn (startup,w) =>
                   (startupRef := startup;
                    ret w))
      in Dojo.attachToElement e wM (!startupRef)
      end

end
