defmodule Vocaloid.CLI do

  alias Vocaloid.Args

  @moduledoc """
  Documentation for the `Vocaloid` vpr file transformer.

  60 is Vocaloid midi note for C3
  """

  @doc """

  """
  def main(args) do
    IO.puts("Vocaloid escript runing")
    #IO.inspect(UUID.uuid1(), label: "uuid")
    case Args.parse_args(args) do
      {:error, errors} ->
        IO.inspect(errors, label: "invalid arguments")
      {:ok, parsed} ->
        case parsed.help do
          true ->
            print_help(parsed)
          false ->
            :ok = process_file(parsed)
          end
      end
  end

  defp process_file(args) do
    sourcefile = Path.join(args.outputdir, args.base <> args.ext)
    # erlang zip only works on files with a `.zip` extension
    # make it so
    inputfile = case args.ext do
      ".zip" ->
        sourcefile
      _      ->
        :ok = File.mkdir_p(args.inputdir)
        zipfile = Path.join(args.inputdir, args.base <> ".zip")
        :ok = File.cp(sourcefile, zipfile)
        zipfile
    end
    erlangfilename = String.to_charlist(inputfile)
    {:ok, ziphandle} = :zip.zip_open(erlangfilename, [:memory])
    {:ok, [{_filename, contents}]} = :zip.zip_get(ziphandle)
    :ok = :zip.zip_close(ziphandle)
    {:ok, json} = Jason.decode(contents)
    %{"tracks" => tracks} = json
    name = args.name
    original = case name do
      :first -> [first | _t] = tracks
                [first]
      _      -> for %{"name" => ^name} = t <- tracks, do: t
    end
    case original do
      [] ->
        IO.inspect(name, label: "You asked to transpose the track:")
        IO.inspect("No track selected to be transformed, tracks available:")
        for t <- tracks, do: IO.inspect(t["name"], label: "track name:")
      _  ->
        [orig] = original
        newtracks = transpose(args.transforms, orig, 1, [])
        {:ok, newjson} = Jason.encode(%{json | "tracks" => tracks ++ newtracks})
        :ok = write_file(args, newjson)
    end
  end

  defp write_file(args, json) do
    timestamp = make_timestamp()
    tmpdir = Path.join([args.outputdir, "Project"])
    jsonfile = Path.join([tmpdir, "sequence.json"])
    :ok = File.mkdir_p(tmpdir)
    IO.inspect(jsonfile, label: "jsonfile")
    zipfile  = Path.join([args.outputdir, args.base <> timestamp <> ".vpr"])
    :ok = File.write(jsonfile, json)
    erlangjsonfile = String.to_charlist(jsonfile)
    erlangzipfile  = String.to_charlist(zipfile)
    {:ok, ^erlangzipfile} = :zip.create(erlangzipfile, [erlangjsonfile])
    :ok
  end

  defp transpose([],      _original, _n, acc), do: acc
  defp transpose([h | t],  original,  n, acc) do
    parts = original["parts"]
    newparts = transpose_parts(h, parts, n, 1, [])
    trackname = "Transposed " <> make_timestamp()
    newtrack = %{original | "parts" => newparts,
                            "name"  => trackname}
    transpose(t, original, n + 1, [newtrack | acc])
  end

  defp transpose_parts([], [], _, _, acc), do: acc
  defp transpose_parts(ts, [], n, m, acc) do
    transformed = length(acc)
    untransformed = length(ts)
    IO.puts("in tranpose #{n} for part #{m}:")
    IO.puts("- #{transformed} parts transformed and #{untransformed} part transforms dropped")
    acc
  end
  defp transpose_parts([], p, n, m, acc) do
    transformed = length(acc)
    untransformed = length(p)
    IO.puts("in tranpose #{n} for part #{m}:")
    IO.puts("- #{transformed} parts transformed and #{untransformed} parts not")
    acc
  end
  defp transpose_parts([h1 | t1], [h2 | t2], n, m, acc) do
    newnotes        = transpose_notes(h2["notes"], h1, n, m, acc)
    newpart         = %{h2 | "notes"        => newnotes}
    transpose_parts(t1, t2, n, m + 1, [newpart |acc])
  end

  defp transpose_notes([], [], _, _, acc), do: acc
  defp transpose_notes(ts, [], n, m, acc) do
    transformed = length(acc)
    untransformed = length(ts)
    IO.puts("in tranpose #{n} for part #{m}:")
    IO.puts("- #{transformed} notes transformed and #{untransformed} transforms dropped")
    acc
  end
  defp transpose_notes([], ns, n, m, acc) do
    transformed = length(acc)
    untransformed = length(ns)
    IO.puts("in tranpose #{n} for part #{m}:")
    IO.puts("- #{transformed} notes transformed and #{untransformed} notes not")
    acc
  end
  defp transpose_notes([h1 | t1], [h2 | t2], n, m, acc) do
    %{"number" => note} = h1
    newacc = case h2 do
                0 -> acc
                n -> [%{h1 | "number" => note + n - 1} | acc]
             end
    transpose_notes(t1, t2, n, m, newacc)
  end

  defp print_help(args) do
    IO.puts("Usage of vocaloid")
    IO.puts("")
    IO.puts("This script takes the following parameters")
    IO.puts("")
    IO.puts("-h or --help (OPTIONAL)")
    IO.puts("    Invokes help.")
    IO.puts("")
    IO.puts("-f <filename> or --file <filename> (REQUIRED)")
    IO.puts("    The path/filename.ext of the file to have the transpositions applied to.")
    IO.puts("")
    IO.puts("-t <filename> or --transpositions <filename> (REQUIRED)")
    IO.puts("    The path/filename.ext of the file containing the transpositions to be")
    IO.puts("    applied.")
    IO.puts("")
    IO.puts("    Transpositions are cardinals - ie 5 means transpose up a 5th")
    IO.puts("    1 means repeat the same note, and 0 is a rest. Can be negative too.")
    IO.puts("")
    IO.puts("    The transposition file is an Erlang term containing a list of lists")
    IO.puts("    a new Vocaloid track will be generated for each list in the top list")
    IO.puts("    and the transposition of the elements in the list will be applied")
    IO.puts("    note by noteto the selected Vocaloid track.")
    IO.puts("")
    IO.puts("    There is a sample Vocaloid track and transposition in ./priv")
    IO.puts("")
    IO.puts("-n <quoted string>  (OPTIONAL)")
    IO.puts("    Name of the Vocaloid track to be transformed.")
    IO.puts("    (If omitted the first track will be selected.)")
    IO.puts("")
    IO.inspect(args, label: "parsed arguments")
    IO.puts("")
    IO.puts("NOTE: if the .ext isn't .zip the file (usually a .vpr) will be copied")
    IO.puts("to a temp directory (.vocaloid_generator) first and renamed before processing.")
  end

  defp make_timestamp() do
      raw       = DateTime.utc_now() |> DateTime.to_string()
      kneaded   = String.replace(raw,       "\.", "_")
      halfbaked = String.replace(kneaded,   "-",  "_")
      cooling   = String.replace(halfbaked, ":",  "_")
      cooked    = String.replace(cooling,   " ",  "_")
      "_" <> cooked
    end

end
