defmodule Cain.Endpoint.History.Detail do
  use Cain.Endpoint

  def get(id) do
    get("/history/detail/#{id}", %{}, %{})
  end

  def get_list(query \\ %{}) do
    get("/history/detail", query, %{})
  end
end
