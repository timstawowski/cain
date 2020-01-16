defmodule Cain.Endpoint.Task.Comment do
  def get_list(id) do
    {:get, "/task/#{id}/comment", %{}, %{}}
  end

  def get(id, comment_id) do
    {:get, "/task/#{id}/comment/#{comment_id}", %{}, %{}}
  end

  def create(id, comment_text) do
    {:post, "/task/#{id}/comment/create", %{}, %{"messgage" => comment_text}}
  end
end
