defmodule Cain.Endpoint.ProcessInstance.Variable do
  def get(%{id: id, variable_name: variable_name}, query \\ %{}) do
    {:get, "/process-instance/#{id}/variables/#{variable_name}", query, %{}}
  end

  def get_list(%{id: id}) do
    {:get, "/process-instance/#{id}/variables", %{}, %{}}
  end
end
