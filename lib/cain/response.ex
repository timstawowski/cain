defprotocol Cain.Response do
  def pre_cast(params)
end

defimpl Cain.Response, for: Map do
  def pre_cast(params) do
    Enum.reduce(params, %{}, fn {key, value}, acc ->
      Map.put(acc, Macro.underscore(key) |> String.to_existing_atom(), value)
    end)
    |> Map.to_list()
  end
end
