defmodule Cain.Response do
  @type response :: %{optional(String.t()) => any()} | %{}

  defmodule Helper do
    def variables_in_return(response, true) when is_map(response) do
      Cain.Variable.parse(response)
    end

    def variables_in_return(response, false), do: response

    @spec pre_cast(Cain.Response.t()) :: map() | :error
    def pre_cast(params) when is_map(params) do
      Enum.reduce(params, %{}, fn {key, value}, acc ->
        Map.put(acc, format_key(key), value)
      end)
      |> Map.to_list()
    end

    def pre_cast(_invalid), do: :error

    defp format_key(key) when is_atom(key) do
      key
    end

    defp format_key(key) when key in ["ended", "suspended"] do
      format_key(key <> "?")
    end

    defp format_key(key) do
      key
      |> Macro.underscore()
      |> String.to_existing_atom()
    end
  end
end
