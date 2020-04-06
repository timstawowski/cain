defmodule Cain.BusinessProcess.DynamicSupervisor do
  use DynamicSupervisor

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_business_process(process_defintion_key) do
    DynamicSupervisor.start_child(__MODULE__, {Cain.BusinessProcess, process_defintion_key})
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
