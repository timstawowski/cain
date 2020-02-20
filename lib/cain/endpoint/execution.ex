defmodule Cain.Endpoint.Execution do
  use Cain.Endpoint

  def get_list(query \\ %{}) do
    get("/execution", query, %{})
  end
end
