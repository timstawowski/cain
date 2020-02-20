defmodule Cain.Endpoint.DecisionDefinition do
  use Cain.Endpoint

  def evaluate({:id, id}, body) do
    evaluate("/decision-definition/#{id}/evaluate", body)
  end

  def evaluate({:key, key}, body) do
    evaluate("/decision-definition/key/#{key}/evaluate", body)
  end

  def evaluate({:key, key, :tenant_id, tenant_id}, body) do
    evaluate("/decision-definition/key/#{key}/tenant-id/#{tenant_id}/evaluate", body)
  end

  def evaluate(path, body) do
    post(path, %{}, body)
  end
end
