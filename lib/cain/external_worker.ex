defmodule Cain.ExternalWorker do
  use GenServer
  require Logger
  alias Cain.Variable

  alias Cain.Endpoint.ExternalTask

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

  # decompose
  def handle_info({reference, function_result}, state) when is_reference(reference) do
    case :ets.take(state.module, reference) do
      [{_reference, task_id, definition_key, business_key}] ->
        Logger.info("External function result is: #{inspect(function_result, pretty: true)}")

        case function_result do
          :ok ->
            ExternalTask.complete(
              task_id,
              %{"workerId" => state.worker_id}
            )

          {:ok, variables} ->
            ExternalTask.complete(
              task_id,
              %{"workerId" => state.worker_id, "variables" => Variable.cast(variables)}
            )

          {:bpmn_error, code, message, variables} ->
            ExternalTask.handle_bpmn_error(task_id, %{
              "workerId" => state.worker_id,
              "errorCode" => code,
              "errorMessage" => message,
              "variables" => Cain.Variable.cast(variables)
            })

          {:incident, message, details, opts} ->
            # TODO: setting retries causes endless-loop
            retries = Keyword.get(opts, :retries, 0)
            retry_time_out_in_ms = Keyword.get(opts, :retry_time_out_in_ms, 3000)

            ExternalTask.handle_failure(task_id, %{
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

        notify_instance(definition_key, business_key)

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

  # decompose
  defp fetch_and_lock(state) do
    %{
      "workerId" => state.worker_id,
      "maxTasks" => state.max_tasks
    }
    |> Map.put("topics", Enum.map(state.topics, &create_topics(&1)))
    |> ExternalTask.fetch_and_lock()
    |> case do
      {:error, message} ->
        IO.warn("Error while fetching topics! Response message: #{message}")

      body ->
        Enum.map(body, fn task -> Map.update!(task, "variables", &Variable.parse/1) end)
        |> Enum.each(&spawn_task(&1, state))
    end
  end

  defp create_topics({topic, _referenced_func, opts}) do
    lock_duration = Keyword.get(opts, :lock_duration, :timer.minutes(2))
    %{"topicName" => Atom.to_string(topic), "lockDuration" => lock_duration}
  end

  # decompose
  defp spawn_task(
         %{"topicName" => topic_name, "id" => task_id} = payload,
         %__MODULE__{topics: topics} = state
       ) do
    {_topic, {module, func, args}, _opts} =
      Enum.find(topics, fn {topic, _func, _opts} ->
        Atom.to_string(topic) == topic_name
      end)

    case :ets.match(state.module, {:"$1", task_id}) do
      [] ->
        %Task{ref: reference} = Task.async(module, func, [payload] ++ args)

        :ets.insert(
          state.module,
          {reference, task_id, payload["processDefinitionKey"], payload["businessKey"]}
        )

      _already_started ->
        :already_started
    end
  rescue
    error ->
      ExternalTask.handle_failure(task_id, %{
        "workerId" => state.worker_id,
        "errorMessage" => "Implementation Error (#{error.__struct__})",
        "errorDetails" => Exception.format(:error, error, __STACKTRACE__),
        "retries" => 0,
        "retryTimeout" => 0
      })

      error
  end

  defp notify_instance(definition_key, business_key) do
    Module.concat(Cain.BusinessProcess, definition_key)
    |> Cain.ProcessInstance.update_state(business_key)
  end

  defp worker_id do
    {:ok, hostname} = :inet.gethostname()

    "cain::#{hostname}#{inspect(self())}"
  end
end
