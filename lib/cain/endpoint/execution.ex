defmodule Cain.Endpoint.Execution do
  use Cain.Endpoint

  def get(%{id: id}) do
    get("/execution/#{id}", %{}, %{})
  end

  def get_list(query \\ %{}) do
    get("/execution", query, %{})
  end
end
