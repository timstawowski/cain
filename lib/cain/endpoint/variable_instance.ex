defmodule Cain.Endpoint.VariableInstance do
  def get_list(query) do
    {:get, "/variable-instance", query, %{}}
  end
end
