defprotocol Cain.Response do
  def pre_cast(params)
end

defimpl Cain.Response, for: Map do
  def pre_cast(params) do
    Enum.reduce(params, %{}, fn {key, value}, acc ->
      Map.put(acc, format_key(key) |> String.to_existing_atom(), value)
    end)
    |> Map.to_list()
  end

  defp format_key(key) when key in ["ended", "suspended"] do
    format_key(key <> "?")
  end

  defp format_key(key) do
    Macro.underscore(key)
  end
end
