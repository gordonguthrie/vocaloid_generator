defmodule Vocaloid.Args do
   defstruct [
      file:       :nil,
      transforms: [],
      dryrun:     false,
      name:       :first
      ]

    def parse_args(args) do
      acc = %Vocaloid.Args{}
      parse_args(args, acc)
   end

   defp parse_args([],                       args), do: validate(args)
   defp parse_args(["-d"               | t], args), do: parse_args(t, %Vocaloid.Args{args | dryrun:     true})
   defp parse_args(["-dryrun"          | t], args), do: parse_args(t, %Vocaloid.Args{args | dryrun:     true})
   defp parse_args(["-f",           f  | t], args), do: parse_args(t, %Vocaloid.Args{args | file:       f})
   defp parse_args(["--file",       f  | t], args), do: parse_args(t, %Vocaloid.Args{args | file:       f})
   defp parse_args(["-t",           ts | t], args), do: parse_args(t, %Vocaloid.Args{args | transforms: ts})
   defp parse_args(["--transforms", ts | t], args), do: parse_args(t, %Vocaloid.Args{args | transforms: ts})
   defp parse_args(["-n",           n  | t], args), do: parse_args(t, %Vocaloid.Args{args | name: n})
   defp parse_args(["--name",       n  | t], args), do: parse_args(t, %Vocaloid.Args{args | name: n})

   defp validate(args) do
      %{file: f, transforms: ts} = args
      case {f, ts} do
         {nil, _}  -> {:error, "transforms ok, but no file"}
         {_,   []} -> {:error, "file ok, but no transforms"}
         {nil, []} -> {:error, "neither file nor transforms"}
         {_,   _}  -> {:ok, args}
      end
   end
end