defmodule Cain.Endpoint.Task.Attachment do
  use Cain.Endpoint

  def get_list(id) do
    get("/task/#{id}/attachment", %{}, %{})
  end

  def get_list(id, attachment_id) do
    get("/task/#{id}/attachment/#{attachment_id}", %{}, %{})
  end

  def create(id, body) do
    post("/task/#{id}/attachment/create", %{}, body)
  end

  def get_binary(id, attachment_id) do
    get("/task/#{id}/attachment/#{attachment_id}/data", %{}, %{})
  end

  def delete(id, attachment_id, opts) do
    delete("/task/#{id}/attachment/#{attachment_id}", %{}, %{}, opts)
  end
end
