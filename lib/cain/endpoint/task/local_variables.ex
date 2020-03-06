defmodule Cain.Endpoint.Task.LocalVariables do
  use Cain.Endpoint

  def get(id, variable_name) do
    get("task/#{id}/localVariables/#{variable_name}", %{}, %{})
  end

  def get_list(id, query \\ %{}) do
    get("task/#{id}/localVariables", query, %{})
  end

  def modify(id, body) do
    post("task/#{id}/localVariables", %{}, body)
  end

  def update(id, variable_name, body) do
    put("task/#{id}/localVariables/#{variable_name}", %{}, body)
  end

  def delete(id, variable_name) do
    delete("task/#{id}/localVariables/#{variable_name}", %{}, %{}, [])
  end
end
