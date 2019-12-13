defmodule DoStuff do
  use Cain.ExternalWorker,
    topics: [
      {:do_stuff, [func: DemoWorker.migrate(), lock_duration: 5000]},
      {:instate, [func: DemoWorker.instate(), lock_duration: 5000]}
    ]
end
