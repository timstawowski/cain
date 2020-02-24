defmodule Cain.Request do
  defmodule Helper do
    def pre_cast_query(query_list) when is_list(query_list) do
      Enum.reduce(query_list, %{}, fn {key, value}, acc ->
        Map.put(acc, format_query(key), value)
      end)
    end

    defp format_query(query_name) when is_atom(query_name) do
      fractured =
        query_name
        |> Atom.to_string()
        |> String.split("_")

      tail =
        fractured
        |> tl()
        |> Enum.join("_")
        |> Macro.camelize()
        |> List.wrap()

      [hd(fractured) | tail] |> Enum.join()
    end
  end
end
