defmodule Cain.Endpoint.ProcessDefinition do
  use Cain.Endpoint

  def start_instance({:id, id}, body) do
    start_instance("/process-definition/#{id}/start", body)
  end

  def start_instance({:key, key}, body) do
    start_instance("/process-definition/key/#{key}/start", body)
  end

  def start_instance({:key, key, :tenant_id, tenant_id}, body) do
    start_instance("/process-definition/key/#{key}/tenant-id/#{tenant_id}/start", body)
  end

  def start_instance(path, body) do
    post(path, %{}, body)
  end

  def restart_process_instance(id, body) do
    post("/process-definition/#{id}/restart", %{}, body)
  end

  def get(%{key: key}) do
    get("/process-definition/key/#{key}")
  end

  def get(%{key: key, tenant_id: tenant_id}) do
    get("/process-definition/key/#{key}/tenant-id/#{tenant_id}")
  end

  def get(path) do
    get(path, %{}, %{})
  end

  def get_diagram(%{id: id}) do
    get_diagram("/process-definition/#{id}/diagram")
  end

  def get_diagram(%{key: key}) do
    get_diagram("/process-definition/key/#{key}/diagram")
  end

  def get_diagram(%{key: key, tenant_id: tenant_id}) do
    get_diagram("/process-definition/key/#{key}/tenant-id/#{tenant_id}/diagram")
  end

  def get_diagram(path) do
    get(path, %{}, %{})
  end
end
