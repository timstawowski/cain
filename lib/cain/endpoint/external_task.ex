defmodule Cain.Endpoint.ExternalTask do
  use Cain.Endpoint

  def get(id) do
    get("/external-task/#{id}", %{}, %{})
  end

  def get_list do
    get("/external-task", %{}, %{})
  end

  def get_list_count do
    get("/external-task/count", %{}, %{})
  end

  def fetch_and_lock(body) do
    post("/external-task/fetchAndLock", %{}, body)
  end

  def complete(id, body) do
    post("/external-task/#{id}/complete", %{}, body)
  end

  def handle_bpmn_error(id, body) do
    post("/external-task/#{id}/bpmnError", %{}, body)
  end

  def handle_failure(id, body) do
    post("/external-task/#{id}/failure", %{}, body)
  end

  def unlock(id) do
    post("/external-task/#{id}/unlock", %{}, %{})
  end

  def extend_lock(id) do
    post("/external-task/#{id}/extendLock", %{}, %{})
  end

  def set_priority(id) do
    put("/external-task/#{id}/priority", %{}, %{})
  end

  def set_retries(id) do
    put("/external-task/#{id}/retries", %{}, %{})
  end

  def set_retries_async do
    post("/external-task/retries-async", %{}, %{})
  end

  def set_retries_sync do
    put("/external-task/retries-sync", %{}, %{})
  end
end
