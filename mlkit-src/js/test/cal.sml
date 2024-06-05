(* Based on Peter Sestoft's ML Server Pages calendar -- sestoft@dina.kvl.dk 2000-01-09 *)
(* mael 2007-09-05 *)

local
    open Date Html
    infix &&
    
    val daynames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    val monthnames = 
	Vector.fromList ["January", "February", "March", "April", "May", "June", "July",
 	                 "August", "September", "October", "November", "December"]

    fun leap y = y mod 4 = 0 andalso y mod 100 <> 0 orelse y mod 400 = 0

    fun daysinmonth year = 
	fn Jan => 31 | Feb => if leap year then 29 else 28
	 | Mar => 31 | Apr => 30 | May => 31 | Jun => 30
	 | Jul => 31 | Aug => 31 | Sep => 30 | Oct => 31
	 | Nov => 30 | Dec => 31

    val tomonthcode = 
	fn 1 => Jan | 2 => Feb | 3 => Mar | 4 => Apr | 5 => May | 6 => Jun
	 | 7 => Jul | 8 => Aug | 9 => Sep | 10 => Oct | 11 => Nov | 12 => Dec
	 | _ => raise Fail "Illegal month number"

    val frommonthcode = 
	fn Jan => 1 | Feb => 2 | Mar => 3 | Apr => 4 
	 | May => 5 | Jun => 6 | Jul => 7 | Aug => 8 
	 | Sep => 9 | Oct => 10 | Nov => 11 | Dec => 12

    fun toDatedate (year, month, day) =
	date { year = year, month = tomonthcode month, day = day, 
	       hour = 12, minute = 0, second = 0, offset = NONE }

    val wdayno = 
	fn Mon => 1 | Tue => 2 | Wed => 3 | Thu => 4 
	 | Fri => 5 | Sat => 6 | Sun => 7

    val dayheader = tr(prmap (th o $) daynames)

    fun mkmonth (year : int) (month : int) wrap = 
	let val firstwdayno = wdayno (weekDay (toDatedate (year, month, 1)))
	    val daysinmonth = daysinmonth year (tomonthcode month)
	    val days = List.tabulate(firstwdayno-1, fn _ => NONE)
		       @ List.tabulate(daysinmonth, fn d => SOME(d+1))
		fun makeday NONE       = Empty
		  | makeday (SOME day) =
		    let val daystring = $ (Int.toString day)
		    in wrap (year, month, day) daystring end
		fun weeks [] = []
		  | weeks days =
		    let val thisweek = List.take(days, Int.min(7, length days))
			val nextweek = List.drop(days, Int.min(7, length days))
			val firstrow = prmap (td o makeday) thisweek
		    in 
			firstrow :: weeks nextweek 
		    end
		val monthheader = 
		    $$[Vector.sub(monthnames, month-1), " ", Int.toString year]
	in 
	    tablea "BORDER" (tr(tha "COLSPAN=7" monthheader)
			    && dayheader && Nl
			    && prsep Nl (tra "ALIGN=RIGHT") (weeks days))
	end
in
    val today = 
	let val dt = fromTimeLocal(Time.now())
	in (year dt, frommonthcode (month dt), day dt) end
    
    fun calmonth year month =
	let fun wrap date s = if date = today then strong s else s
	in mkmonth year month wrap end

    fun calyear year = 
	let fun prtab(n, f) = List.foldr (op &&) Empty (List.tabulate(n, f))
	    fun mkcalrow r = 
		tra "VALIGN=TOP" (prtab(3, 
					fn s => td(calmonth year (3*r+s+1))))
	in 
	    tablea "BORDER" (prtab(4, mkcalrow))
	end

    val year = #1 today

    val page =
      html(head(title($"HTML example: calendar for year " && $(Int.toString year))) &&
           bodya "BGCOLOR='#fbf2e7'" (
           h2 ($"HTML example: calendar for year " && $(Int.toString year)) &&
           calyear year &&
           br && 
           h2($"Your free bonus: a calendar for a random month") &&
           let open Random 
               val gen = newgen()
           in calmonth (range (1900,2100) gen) (range (1,12) gen) 
           end)) 

    val _ = printhtml page
end
