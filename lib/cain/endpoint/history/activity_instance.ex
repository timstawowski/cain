defmodule Cain.Endpoint.History.ActivityInstance do
  use Cain.Endpoint

  def get_list(query) do
    get("/history/activity-instance", query, %{})
  end
end
