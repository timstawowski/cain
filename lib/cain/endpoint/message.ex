defmodule Cain.Endpoint.Message do
  use Cain.Endpoint

  def correlate(body) do
    post("/message", %{}, body)
  end
end
