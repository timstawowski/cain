defmodule Cain.Endpoint.ProcessDefinition do
  def start_instance(%{id: id}, body) do
    start_instance("/process-definition/#{id}/start", body)
  end

  def start_instance(%{key: key}, body) do
    start_instance("/process-definition/key/#{key}/start", body)
  end

  def start_instance(%{key: key, tenant_id: tenant_id}, body) do
    start_instance("/process-definition/key/#{key}/tenant-id/#{tenant_id}/start", body)
  end

  def start_instance(path, body) do
    {:post, path, %{}, body}
  end

  def restart_process_instance(id, body) do
    {:post, "/process-definition/#{id}/restart", %{}, body}
  end
end
