defmodule Cain.ProcessInstance.DynamicSupervisor do
  use DynamicSupervisor

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_instance(process_instance) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {Cain.ProcessInstance, process_instance}
    )
  end

  @impl true
  def init(_init_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
