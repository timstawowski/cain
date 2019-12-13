defmodule Cain.Endpoint.History.ActivityInstance do
  def get_list(query) do
    {:get, "/history/activity-instance", query, %{}}
  end
end
