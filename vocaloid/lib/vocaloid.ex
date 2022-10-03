defmodule Vocaloid.CLI do

  alias Vocaloid.Args

  @moduledoc """
  Documentation for the `Vocaloid` vpr file transformer.

  60 is Vocaloid midi note for C3
  """

  @doc """

  """
  def main(args) do
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
        newtracks = transpose(args.transforms, orig, 1, !args.silent, [])
        {:ok, newjson} = Jason.encode(%{json | "tracks" => tracks ++ newtracks})
        :ok = write_file(args, newjson)
    end
  end

  defp write_file(args, json) do
    timestamp = make_timestamp()
    projectdir = Path.join([args.workingdir, "Project"])
    jsonfile = Path.join([projectdir, "sequence.json"])
    :ok = File.mkdir_p(projectdir)
    case File.rm(jsonfile) do
      :ok               -> :ok
      {:error, :enoent} -> :ok
      {:error, e}       -> IO.inspect(jsonfile, label: "Attempting to delete")
                           IO.inspect(e, label: "failed with error")
                           exit(1)
    end
    zipfile  = Path.join([args.outputdir, args.base <> timestamp <> ".vpr"])
    :ok = File.write(jsonfile, json)
    erlangjsonpath = Path.join(["./", "Project/sequence.json"])
    erlangjsonfile = String.to_charlist(erlangjsonpath)
    erlangzipfile  = String.to_charlist(zipfile)
    {:ok, ^erlangzipfile} = :zip.create(erlangzipfile, [erlangjsonfile], [{:cwd, args.workingdir}])
    :ok
  end

  defp transpose([],      _original, _n, _verbsose, acc), do: Enum.reverse(acc)
  defp transpose([h | t],  original,  n,  verbose, acc) do
    parts = original["parts"]
    newparts = transpose_parts(h, parts, n, 1, verbose, [])
    trackname = "VGen_Transposed_" <> Integer.to_string(n)
    newtrack = %{original | "parts" => newparts,
                            "name"  => trackname}
    transpose(t, original, n + 1, verbose, [newtrack | acc])
  end

  defp transpose_parts([], [], _, _, _verbose, acc), do: acc
  defp transpose_parts(ts, [], n, m,  verbose, acc) do
    transformed = length(acc)
    untransformed = length(ts)
    if verbose do
      IO.puts("in tranpose #{n} for part #{m}:")
      IO.puts("- #{transformed} parts transformed and #{untransformed} part transforms dropped")
    end
    acc
  end
  defp transpose_parts([], p, n, m, verbose, acc) do
    transformed = length(acc)
    untransformed = length(p)
    if verbose do
      IO.puts("in tranpose #{n} for part #{m}:")
      IO.puts("- #{transformed} parts transformed and #{untransformed} parts not")
    end
    acc
  end
  defp transpose_parts([h1 | t1], [h2 | t2], n, m, verbose, acc) do
    newnotes        = transpose_notes(h2["notes"], h1, n, m, verbose, acc)
    newpart         = %{h2 | "notes"        => newnotes}
    transpose_parts(t1, t2, n, m + 1, verbose, [newpart |acc])
  end

  defp transpose_notes([], [], _, _, _verbose, acc), do: acc
  defp transpose_notes(ts, [], n, m,  verbose, acc) do
    transformed = length(acc)
    untransformed = length(ts)
    if verbose do
      IO.puts("in tranpose #{n} for part #{m}:")
      IO.puts("- #{transformed} notes transformed and #{untransformed} notes not")
    end
    acc
  end
  defp transpose_notes([], ns, n, m, verbose, acc) do
    transformed = length(acc)
    untransformed = length(ns)
    if verbose do
      IO.puts("in tranpose #{n} for part #{m}:")
      IO.puts("- #{transformed} notes transformed and last #{untransformed} transforms dropped")
    end
    acc
  end
  defp transpose_notes([h1 | t1], [h2 | t2], n, m, verbose, acc) do
    %{"number" => note} = h1
    newacc = cond do
                h2 <  0 -> [%{h1 | "number" => note + h2 + 1} | acc]
                h2 == 0 -> acc
                h2 >  0 -> [%{h1 | "number" => note + h2 - 1} | acc]
             end
    transpose_notes(t1, t2, n, m, verbose, newacc)
  end

  defp print_help(args) do
    IO.puts("Usage of vocaloid")
    IO.puts("")
    IO.puts("This script takes the following parameters")
    IO.puts("")
    IO.puts("-h or --help (OPTIONAL)")
    IO.puts("    Invokes help - the command doesn't run, can be used to inspect parsed args")
    IO.puts("")
    IO.puts("-f <filename> or --file <filename> (REQUIRED)")
    IO.puts("    The path/filename.ext of the file to have the transpositions applied to.")
    IO.puts("")
    IO.puts("-n <quoted string> (OPTIONAL)")
    IO.puts("    Name of the Vocaloid track to be transformed.")
    IO.puts("    (If omitted the first track will be selected.)")
    IO.puts("")
    IO.puts("-s or --silent (OPTIONAL)")
    IO.puts("    Supresses output about applied or not applied transforms by note and part.")
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
