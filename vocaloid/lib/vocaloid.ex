defmodule Vocaloid.CLI do

  alias Vocaloid.Args

  @tempdir ".vocaloid_generator"

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
        case parsed.dryrun do
          true ->
            IO.inspect(parsed, label: "parsed")
          false ->
            process_file(String.to_charlist(parsed.file))
          end
      end
  end

  defp process_file(file) do
    _dir  = Path.dirname(file)
    ext  = Path.extname(file)
    _base = Path.basename(file, ext)
    # the Erlang module `zip` expects a `.zip` file extension
    # make it so with a temporary file

    _transformed = case ext do
      ".zip" -> transform(file)
      _      -> transform_temp_file(file)
    end
  end

  defp transform_temp_file(file) do
    dir  = Path.dirname(file)
    ext  = Path.extname(file)
    base = Path.basename(file, ext)
    tmpdir = Path.join(dir, @tempdir)
    :ok = File.mkdir_p(tmpdir)
    zipfile = Path.join([tmpdir, base <> ".zip"])
    :ok = File.cp(file, zipfile)
    transform(String.to_charlist(zipfile))
  end

  defp transform(file) do
    IO.inspect(file, label: "in transform")
    {:ok, ziphandle} = :zip.zip_open(file, [:memory])
    {:ok, [{_filename, contents}]} = :zip.zip_get(ziphandle)
    :ok = :zip.zip_close(ziphandle)
    {:ok, json} = Jason.decode(contents)
    %{"tracks" => tracks} = json
    for t <- tracks, do: parse_parts(t["parts"])
  end

  defp parse_parts(parts) do
    for p <- parts, do: process_notes(p["notes"])
  end

  defp process_notes(notes) do
    for n <- notes, do: IO.inspect({n["number"], n["phoneme"]}, label: "note number")
  end

end
