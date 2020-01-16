defmodule Cain.ExternalWorker do
  use GenServer
  require Logger

  defstruct [
    :max_tasks,
    :worker_id,
    :module,
    :use_priority,
    :topics,
    :polling_interval
  ]

  @default_params [
    max_tasks: 3,
    use_priority: false,
    polling_interval: :timer.seconds(3)
  ]

  # #####
  #
  # api code ...
  #

  @callback register_topics() :: [{atom(), {atom(), atom(), list()}, list()}]

  defmacro __using__(inital_params) do
    params =
      @default_params
      |> Enum.map(fn {k, v} -> {k, Keyword.get(inital_params, k, v)} end)
      |> Keyword.put(:module, __CALLER__.module)
      |> config()

    quote do
      @behaviour Cain.ExternalWorker

      def __params__ do
        unquote(Macro.escape(params))
      end

      def start_link do
        GenServer.start_link(Cain.ExternalWorker, __params__())
      end
    end
  end

  defp config(config \\ %__MODULE__{}, params) do
    %__MODULE__{
      config
      | max_tasks: Keyword.get(params, :max_tasks),
        use_priority: Keyword.get(params, :use_priority),
        polling_interval: Keyword.get(params, :polling_interval),
        module: Keyword.get(params, :module)
    }
  end

  # #####
  #
  # Worker code ...
  #

  def init(%__MODULE__{} = config) do
    :ets.new(config.module, [:named_table])
    {:ok, config, {:continue, :init}}
  end

  def handle_continue(:init, state) do
    new_state = %__MODULE__{
      state
      | worker_id: worker_id(),
        topics: apply(state.module, :register_topics, [])
    }

    schedule_polling(new_state)
    {:noreply, new_state}
  end

  def handle_info(:poll, state) do
    fetch_and_lock(state)
    schedule_polling(state)
    {:noreply, state}
  end

  # out lagern und
  def handle_info({reference, function_result}, state) when is_reference(reference) do
    case :ets.take(state.module, reference) do
      [{_reference, task_id}] ->
        Logger.warn("Function result is: #{inspect(function_result, pretty: true)}")
        # variables = Cain.Variable.cast(response, state.response)
        case function_result do
          :ok ->
            Cain.Endpoint.ExternalTask.complete(
              task_id,
              %{"workerId" => state.worker_id}
            )

          {:ok, variables} ->
            Cain.Endpoint.ExternalTask.complete(
              task_id,
              %{"workerId" => state.worker_id, "variables" => variables}
            )

          {:bpmn_error, code, message, variables} ->
            Cain.Endpoint.ExternalTask.handle_bpmn_error(task_id, %{
              "workerId" => state.worker_id,
              "errorCode" => code,
              "errorMessage" => message,
              "variables" => variables
            })

          {:incident, message, details, opts} ->
            retries = Keyword.get(opts, :retries, 0)
            retry_time_out_in_ms = Keyword.get(opts, :retry_time_out_in_ms, 3000)

            Cain.Endpoint.ExternalTask.handle_failure(task_id, %{
              "workerId" => state.worker_id,
              "errorMessage" => message,
              "errorDetails" => details,
              "retries" => retries,
              "retryTimeout" => retry_time_out_in_ms
            })

          error ->
            Logger.error(
              "External_Worker recievd invalid function result: #{inspect(error, pretty: true)}"
            )
        end
        |> case do
          :ok ->
            nil

          valid_request ->
            Cain.Endpoint.submit(valid_request)
        end

        {:noreply, state}

      [] ->
        Logger.debug("No task for completed reference found")
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp schedule_polling(state) do
    Process.send_after(self(), :poll, state.polling_interval)
  end

  defp fetch_and_lock(state) do
    %{
      "workerId" => state.worker_id,
      "maxTasks" => state.max_tasks
    }
    |> Map.put("topics", Enum.map(state.topics, &create_topics(&1)))
    |> Cain.Endpoint.ExternalTask.fetch_and_lock()
    |> Cain.Endpoint.submit()
    |> case do
      {:ok, body} ->
        import Cain.Variable, only: [parse: 1]

        Enum.map(body, fn task -> Map.update!(task, "variables", &parse(&1)) end)
        |> Enum.each(&spawn_task(&1, state))

      _ ->
        IO.warn("Error while fetching topics!")
    end
  end

  def create_topics({topic, _referenced_func, opts}) do
    lock_duration = Keyword.get(opts, :lock_duration, :timer.minutes(2))
    %{"topicName" => Atom.to_string(topic), "lockDuration" => lock_duration}
  end

  defp spawn_task(
         %{"topicName" => topic_name, "id" => task_id} = payload,
         %__MODULE__{topics: topics} = state
       ) do
    # try do
    {_topic, {module, func, args}, _opts} =
      Enum.find(topics, fn {topic, func, _opts} ->
        Atom.to_string(topic) == topic_name
      end)

    %Task{ref: reference} = Task.async(module, func, [payload] ++ args)
    :ets.insert(state.module, {reference, task_id})
  rescue
    error ->
      Cain.Endpoint.ExternalTask.handle_failure(task_id, %{
        "workerId" => state.worker_id,
        "errorMessage" => "Implementation Error (#{error.__struct__})",
        "errorDetails" => Exception.format(:error, error, __STACKTRACE__),
        "retries" => 0,
        "retryTimeout" => 0
      })
      |> Cain.Endpoint.submit()

      error
      # end
  end

  defp worker_id do
    {:ok, hostname} = :inet.gethostname()

    "cain::#{hostname}#{inspect(self())}"
  end
end
