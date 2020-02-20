defmodule Cain.Endpoint.VariableInstance do
  use Cain.Endpoint

  def get_list(query) do
    get("/variable-instance", query, %{})
  end
end
