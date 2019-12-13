defmodule Cain.Endpoint.Job do
  def execute(id) do
    {:post, "/job/#{id}/execute", %{}, %{}}
  end
end
