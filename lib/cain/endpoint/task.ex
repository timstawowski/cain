defmodule Cain.Endpoint.Task do
  def get(id) do
    {:get, "/task/#{id}", %{}, %{}}
  end

  def get_list(query \\ %{}) do
    {:get, "/task", query, %{}}
  end

  def get_task_count(query \\ %{}) do
    {:get, "/task/count", query, %{}}
  end

  # maybe more comfortable way then just the plain body?
  def claim(id, user_id) do
    {:post, "/task/#{id}/claim", %{}, %{"userId" => user_id}}
  end

  def unclaim(id) do
    {:post, "/task/#{id}/unclaim", %{}, %{}}
  end

  def complete(id, body) do
    {:post, "/task/#{id}/complete", %{}, body}
  end

  def submit_form(id, body) do
    {:post, "/task/#{id}/submit-form", %{}, body}
  end

  def resolve(id, body) do
    {:post, "/task/#{id}/resolve", %{}, body}
  end

  def set_assignee(id, user_id) do
    {:post, "/task/#{id}/assignee", %{}, %{"userId" => user_id}}
  end

  def delegate(id, user_id) do
    {:post, "/task/#{id}/delegate", %{}, %{"userId" => user_id}}
  end

  def get_deployed_form(id) do
    {:get, "/task/#{id}/deployed-form", %{}, %{}}
  end

  def get_rendered_form(id) do
    {:get, "/task/#{id}/rendered-form", %{}, %{}}
  end

  def get_task_form_variables(id, query \\ %{}) do
    {:get, "/task/#{id}/form-variables", query, %{}}
  end

  def create(body) do
    {:post, "/task/create", %{}, body}
  end

  def update(id, body) do
    {:put, "/task/#{id}/", %{}, body}
  end
end
