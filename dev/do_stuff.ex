defmodule Vortex.Auth.Resource do
  defstruct [
    :uid,
    :auth_strategy,
    :data,
    :roles
  ]
end

defmodule Vortex.System do
  defstruct [
    :node,
    :pid,
    :timestamp
  ]

  defmodule Root do
    defstruct [
      :authorized_commands
    ]
  end

  def spawn(command) do
    %Vortex.Auth.Resource{
      uid: uid(),
      auth_strategy: __MODULE__,
      data: %__MODULE__{
        node: "node(",
        pid: self(),
        timestamp: NaiveDateTime.utc_now()
      },
      roles: [
        %Vortex.System.Root{
          authorized_commands: [command]
        }
      ]
    }
  end

  defp uid do
    "vortex_root::" <> "CAMUNDA"
  end
end

defmodule DoStuff do
  require Vortex.System

  use Cain.ExternalWorker,
    topics: [
      # {:do_stuff,
      #  [
      #    func: DemoWorker.instate(%Vortex.Auth.Resource{}),
      #    lock_duration: 5000
      #  ]}
      {:instate, [func: DemoWorker.instate(), lock_duration: 5000]}
    ]
end
