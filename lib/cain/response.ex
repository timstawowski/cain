defmodule Cain.Response do
  @type t :: %{optional(String.t()) => any()} | %{}

  defmodule Helper do
    def variables_in_return(%{"variables" => variables} = response, true) when is_map(response) do
      Map.put(response, "variables", Cain.Variable.parse(variables))
    end

    def variables_in_return(response, true) when is_map(response) do
      Cain.Variable.parse(response)
    end

    def variables_in_return(response, false), do: response

    @spec pre_cast(Cain.Response.t()) :: list() | :error
    def pre_cast(params) when is_map(params) do
      Enum.reduce(params, %{}, fn {key, value}, acc ->
        if format_key(key) != :needles do
          Map.put(acc, format_key(key), value)
        end
      end)
      |> Map.to_list()
    end

    def pre_cast(_invalid), do: :error

    defp format_key(key) when is_atom(key) do
      key
    end

    defp format_key(key) when key in ["ended", "suspended", "startableInTaskList"] do
      format_key(key <> "?")
    end

    defp format_key(key) do
      try do
        key
        |> Macro.underscore()
        |> String.to_existing_atom()
      rescue
        ArgumentError -> :needless
      end
    end
  end
end
