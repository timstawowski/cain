defmodule Cain do
  @moduledoc """
  Either use DecisionTable or BusinessProcess
  """
  use Application
  import Supervisor.Spec, only: [worker: 2, supervisor: 2]

  def start(_type, _args) do
    children = [
      worker(Cain.Endpoint, []),
      supervisor(Cain.BusinessProcess.Registry, []),
      supervisor(Cain.BusinessProcess.DynamicSupervisor, []),
      supervisor(Cain.ProcessInstance.Registry, []),
      supervisor(Cain.ProcessInstance.DynamicSupervisor, []),
      supervisor(Cain.ProcessInstance.ActivityInstance.Registry, []),
      supervisor(Cain.ProcessInstance.ActivityInstance.DynamicSupervisor, [])
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
