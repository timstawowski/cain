defmodule Cain.Endpoint.ProcessInstance do
  def get(id) do
    {:get, "/process-instance/#{id}", %{}, %{}}
  end

  def get_activity_instance(id) do
    {:get, "/process-instance/#{id}/activity-instances", %{}, %{}}
  end

  def get_list(query \\ %{}) do
    {:get, "/process-instance", query, %{}}
  end

  def delete(id, query \\ %{}) do
    {:delete, "/process-instance/#{id}", query, %{}}
  end
end
