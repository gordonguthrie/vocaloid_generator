defmodule Vocaloid.Args do
   defstruct [
      file:     :nil
      ]

    def parse_args(args) do
      acc = %Vocaloid.Args{}
      parse_args(args, acc)
   end

   defp parse_args([],                args), do: validate(args)
   defp parse_args(["-f",     f | t], args), do: parse_args(t, %Vocaloid.Args{args | file:       f})
   defp parse_args(["--file", f | t], args), do: parse_args(t, %Vocaloid.Args{args | file:       f})

   defp validate(args) do
      args
   end
end