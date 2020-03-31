defmodule Cain.BusinessProcess.DynamicSupervisor do
  use DynamicSupervisor

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_business_process(process_defintion) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {Cain.BusinessProcess, process_defintion}
    )
  end

  @impl true
  def init(_init_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
