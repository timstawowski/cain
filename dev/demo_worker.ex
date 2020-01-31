defmodule DemoWorker do
  use Cain.ExternalWorker,
    max_tasks: 2,
    use_priority: true,
    polling_interval: 2000

  def register_topics() do
    [{:add, {Math, :add, []}, [lock_duration: 1]}]
  end
end
