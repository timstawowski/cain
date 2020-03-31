defmodule Cain.Endpoint.ProcessInstance.Variables do
  use Cain.Endpoint

  def get(%{id: id, variable_name: variable_name}, query \\ %{}) do
    get("/process-instance/#{id}/variables/#{variable_name}", query, %{})
  end

  def get_list(id, deserialize_values? \\ false) do
    get("/process-instance/#{id}/variables", %{"deserializeValues" => deserialize_values?}, %{})
  end

  def put_process_variable(%{id: id, var_name: var_name, var_body: var_body}) do
    put("/process-instance/#{id}/variables/#{var_name}", %{}, var_body)
  end
end
