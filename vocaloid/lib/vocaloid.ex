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
            process_file(parsed)
          end
      end
  end

  defp process_file(args) do
    IO.inspect(args, label: "args is")
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
    # dump(tracks)
    name = args.name
    original = case name do
      :first -> [first | _t] = tracks
                [first]
      _      -> for %{"name" => ^name} = t <- tracks, do: t
    end
    # IO.inspect(original, label: "original to transform")
    case original do
      [] ->
        IO.inspect(name, label: "You asked to transpose the track:")
        IO.inspect("No track selected to be transformed, tracks available:")
        for t <- tracks, do: IO.inspect(t["name"], label: "track name:")
      _  ->
        [orig] = original
        newtracks = transpose(args.transforms, orig, [])
    end
  end

  defp transpose([],      _original, acc), do: acc
  defp transpose([h | t], original,  acc) do
    IO.inspect(h, label: "apply transform:")
    IO.inspect(original["parts"], label: "to parts:")
    IO.inspect(length(original["parts"]), label: "number of parts")
    transpose(t, original, acc)
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

  defp dump(tracks) do
    for t <- tracks, do: IO.inspect(Map.keys(t), label: "track keys")
    for t <- tracks, do: IO.inspect(t["name"], label: "track name")
    for t <- tracks, do: parse_parts(t["parts"])
  end

  defp parse_parts(parts) do
    for p <- parts, do: IO.inspect(Map.keys(p), label: "part keys")
    for p <- parts, do: process_notes(p["notes"])
  end

  defp process_notes(_notes) do
    #for n <- notes, do: IO.inspect(Map.keys(n))
  end

end
