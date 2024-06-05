structure FileUtil = struct

fun deleteFile (f:string):unit = OS.FileSys.remove f handle _ => ()

fun readFile f =
    let val is = TextIO.openIn f
    in (TextIO.inputAll is before TextIO.closeIn is)
       handle X => (TextIO.closeIn is; raise X)
    end

fun trimWS s =
    if size s = 0 then s
    else if Char.isSpace (String.sub(s,size s - 1)) then
      trimWS (String.extract(s,0,SOME(size s - 1)))
    else s

fun systemOut cmd =
    let val f = OS.FileSys.tmpName()
        val cmd = cmd ^ " > " ^ f
    in if OS.Process.isSuccess(OS.Process.system cmd) then
         readFile f before deleteFile f
       else raise Fail ("FileUtil.systemOut.Failed executing the command '" ^ cmd ^ "'")
    end

local
fun sourcesMlb mlbfile =
    let val s = readFile mlbfile
        val ts = String.tokens Char.isSpace s
        (* eliminate tokens with $ in them *)
        val ts = List.filter (not o (CharVector.exists (fn c => c = #"$"))) ts
        (* include only files with sml/sig/mlb-extensions *)
        val ts = List.filter (fn t =>
                                 case OS.Path.ext t of
                                     SOME e => e = "sml" orelse e = "sig" orelse e = "mlb" orelse e = "fun"
                                   | NONE => false) ts
    in ts
    end

infix |>
fun a |> f = f a

fun mlbsInMlb mlbfile =
    let val dir = OS.Path.dir mlbfile
    in sourcesMlb mlbfile |>
       List.filter (fn f => OS.Path.ext f = SOME "mlb") |>
       map (fn f => OS.Path.concat (dir,f) |> OS.Path.mkCanonical)
    end

fun implsInMlb mlbfile =
    let val dir = OS.Path.dir mlbfile
    in sourcesMlb mlbfile |>
       List.filter (fn f => OS.Path.ext f = SOME "sml" orelse OS.Path.ext f = SOME "sig" orelse OS.Path.ext f = SOME "fun") |>
       map (fn f => OS.Path.concat (dir,f) |> OS.Path.mkCanonical)
    end

fun allMlbsInMlb0 (mlbfile,acc) =
    if List.exists (fn f => f = mlbfile) acc then acc
    else let val mlbs = mlbsInMlb mlbfile
         in List.foldl allMlbsInMlb0 (mlbfile::acc) mlbs
         end

fun allMlbsInMlb mlbfile = allMlbsInMlb0 (mlbfile,nil)

fun lines_impl f =
    length (String.fields (fn c => c = #"\n") (readFile f))
    handle _ => 0

in

fun lines f =
    case OS.Path.ext f of
        SOME "sig" => lines_impl f
      | SOME "sml" => lines_impl f
      | SOME "mlb" =>
        let val mlbs = allMlbsInMlb f |>
                       List.map (fn f => (f, implsInMlb f |> map lines_impl |> List.foldl (op +) 0))
            val () = List.app (fn (f,n) => print (f ^ " : " ^ Int.toString n ^ "\n")) mlbs
        in map #2 mlbs |> List.foldl (op +) 0
        end
      | _ => 0

fun linesOfFile f = lines f
end

end
