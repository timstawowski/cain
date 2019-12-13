defmodule Cain do
  @moduledoc """
  Either use DecisionTable or BusinessProcess
  """
  use Application

  def start(_type, _args) do
    children = [
      # Supervisor.Spec.supervisor(Cain.ProcessInstance.Registry, []),
      # Supervisor.Spec.supervisor(Cain.ProcessInstance.Supervisor, [])
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
