defmodule Cain.Endpoint.Execution.MessageEventSubscription do
  use Cain.Endpoint

  def get(id, message_name) do
    get("/execution/#{id}/messageSubscriptions/#{message_name}", %{}, %{})
  end

  def trigger(id, message_name, variables) do
    post("/execution/#{id}/messageSubscriptions/#{message_name}", %{}, variables)
  end
end
