defmodule Cain.Endpoint.Task.IdentityLinks do
  use Cain.Endpoint

  def get_list(id) do
    get("task/#{id}/identity-links", %{}, %{})
  end

  def add(id, group_id, type) do
    post("task/#{id}/identity-links", %{}, %{"groupId" => group_id, "type" => type})
  end

  # mit hans klären -> REST-Doku dazu!
  def delete(id, body) do
    post("task/#{id}/identity-links/delete", %{}, body)
  end
end
