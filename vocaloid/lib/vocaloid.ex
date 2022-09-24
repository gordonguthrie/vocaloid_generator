defmodule Vocaloid.CLI do

  alias Vocaloid.Args

  @moduledoc """
  Documentation for the `Vocaloid` vpr file transformer.
  """

  @doc """

  """
  def main(args) do
    IO.puts("Vocaloid escript runing")
    parsed = Args.parse_args(args)
    {:ok, ziphandle} = :zip.zip_open(String.to_charlist(parsed.file), [:memory])
    {:ok, [{_filename, contents}]} = :zip.zip_get(ziphandle)
    :ok = :zip.zip_close(ziphandle)
    json = Jason.decode(contents)
    IO.inspect(json, label: "json")
  end


end
