defmodule Vocaloid.Args do
   defstruct [
      help:       false,
      origfile:   :nil,
      inputdir:   :nil,
      workingdir: :nil,
      outputdir:  :nil,
      base:       :nil,
      ext:        :nil,
      transforms: [],
      silent:     false,
      name:       :first
      ]

     @tempdir ".vocaloid_generator"

    def parse_args(args) do
      acc = %Vocaloid.Args{}
      parse_args(args, acc)
   end

   defp parse_args([],                           args), do: validate(args)
   defp parse_args(["-h"                   | t], args), do: parse_args(t, %Vocaloid.Args{args | help:       true})
   defp parse_args(["--help"               | t], args), do: parse_args(t, %Vocaloid.Args{args | help:       true})
   defp parse_args(["-s"                   | t], args), do: parse_args(t, %Vocaloid.Args{args | silent:     true})
   defp parse_args(["--silent"             | t], args), do: parse_args(t, %Vocaloid.Args{args | silent:     true})
   defp parse_args(["-t",               ts | t], args), do: parse_args(t, %Vocaloid.Args{args | transforms: ts})
   defp parse_args(["--transpositions", ts | t], args), do: parse_args(t, %Vocaloid.Args{args | transforms: ts})
   defp parse_args(["-n",               n  | t], args), do: parse_args(t, %Vocaloid.Args{args | name:       n})
   defp parse_args(["--name",           n  | t], args), do: parse_args(t, %Vocaloid.Args{args | name:       n})
   defp parse_args(["-f",               f  | t], args), do: parse_args(["--file", f | t], args)
   defp parse_args(["--file",           f  | t], args) do
      dir  = Path.dirname(f)
      ext  = Path.extname(f)
      base = Path.basename(f, ext)

      workingdir = Path.join(dir, @tempdir)
      inputdir = case ext do
         ".zip" -> dir
         _      -> workingdir
      end
      newargs = %Vocaloid.Args{args | origfile:   f,
                                      base:       base,
                                      inputdir:   inputdir,
                                      workingdir: workingdir,
                                      outputdir:  dir,
                                      ext:        ext}
      parse_args(t, newargs)
   end

   defp validate(args) do
      %{origfile: f, transforms: ts} = args
      resp = case parse_transforms(ts) do
         {:ok, newts} ->
            case {f, ts} do
               {nil, _}  -> {:error, "transforms ok, but no file"}
               {_,   []} -> {:error, "file ok, but no transforms"}
               {nil, []} -> {:error, "neither file nor transforms"}
               {_,   _}  -> {:ok, %{args | transforms: newts}}
            end
          {:error, e} ->
            {:error, e}
         end
      case args.help do
         true ->
            case resp do
               {:ok, a}    -> {:ok, a}
               {:error, x} -> IO.inspect(x, label: "command would have failed with:")
                              {:ok, args}
            end
         false ->
            resp
         end
   end

   defp parse_transforms(ts) do
      case File.exists?(ts) do
         true ->
            {:ok, [contents]} = :file.consult(ts)
            {:ok, contents}
         false ->
            {:error, "file with transforms doesn't exist"}
      end
   end

end