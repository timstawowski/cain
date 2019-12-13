defmodule DoStuff do
  use Cain.ExternalWorker,
    topics: [
      {:instate,
       [func: DemoWorker.instate(%Vortex.Auth.Resource{name: "test"}), lock_duration: 5000]}
      # {:instate, [func: DemoWorker.instate(), lock_duration: 5000]}
    ]
end

defmodule Vortex.Auth.Resource do
  defstruct [
    :name
  ]
end
