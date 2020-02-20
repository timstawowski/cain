defmodule Cain.Endpoint.Job do
  use Cain.Endpoint

  def execute(id) do
    post("/job/#{id}/execute", %{}, %{})
  end
end
