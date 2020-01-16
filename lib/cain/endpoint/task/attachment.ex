defmodule Cain.Endpoint.Task.Attachment do
  def get_list(id) do
    {:get, "/task/#{id}/attachment", %{}, %{}}
  end

  def get_list(id, attachment_id) do
    {:get, "/task/#{id}/attachment/#{attachment_id}", %{}, %{}}
  end

  def create(id, body) do
    {:post, "/task/#{id}/attachment/create", %{}, body}
  end

  def get_binary(id, attachment_id) do
    {:get, "/task/#{id}/attachment/#{attachment_id}/data", %{}, %{}}
  end

  def delete(id, attachment_id) do
    {:delete, "/task/#{id}/attachment/#{attachment_id}", %{}, %{}}
  end
end
