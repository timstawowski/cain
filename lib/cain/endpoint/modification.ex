defmodule Cain.Endpoint.Modification do
  def execute(body) do
    {:post, "modification/execute", %{}, body}
  end
end
