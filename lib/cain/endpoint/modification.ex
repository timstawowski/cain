defmodule Cain.Endpoint.Modification do
  use Cain.Endpoint

  def execute(body) do
    post("modification/execute", %{}, body)
  end
end
