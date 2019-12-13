defmodule Cain.Endpoint.Message do
  def correlate(body) do
    {:post, "/message", %{}, body}
  end
end
