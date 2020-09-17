defmodule Cain.ExternalWorker do
  use GenServer

  alias Cain.{Endpoint, Endpoint.ExternalTask, Variable}

  @default_ms 2000

  defstruct [
    :worker_id,
    :module,
    :topics,
    max_tasks: 3,
    use_priority: false,
    polling_interval: @default_ms,
    workload: %{}
  ]

  @callback register_topics() :: [{atom(), {atom(), atom(), list()}, list()}]

  defmacro __using__(opts) do
    init_args = Keyword.put_new(opts, :module, __CALLER__.module)

    Module.put_attribute(__CALLER__.module, :init_args, init_args)

    quote do
      @behaviour Cain.ExternalWorker

      def start_link do
        GenServer.start_link(Cain.ExternalWorker, @init_args, name: __MODULE__)
      end

      @doc """
      Updates following worker attributes at runtime.
      - `max_tasks` to return on a fetch and lock call.
      - `use_priority` indicates whether the task should be fetched based on its priority or arbitrarily.
      - `polling_interval` in milliseconds, max: 1.800.000ms.
      """
      @spec update(keyword()) :: :ok
      def update(opts) when is_list(opts) do
        opts = Keyword.drop(opts, [:worker_id, :topics, :retries])
        Cain.ExternalWorker.__update__(__MODULE__, opts)
      end

      @doc """
      Creates a valid success result.
      Accepts an map with atom as keys for adding process variables.
      Local variables are not supported yet.
      """
      @spec success(%{atom() => any()}) :: {:ok, map()}
      def success(variables \\ %{}) do
        {:ok, variables}
      end

      @doc """
      Invokes a scheduled retry cycle.
      Add a `error_msg` with a max of 666 characters to indicate the reason of the failure and `details` for a detailed error description.
      A number of `retries` must be >= 0 to indiciate of how often the task should be retried.
      The `retry_timeout` in milliseconds defines a limit before the external task becomes available again for fetching.
      Must be >= 0.
      """
      @spec retry(String.t(), String.t(), pos_integer(), pos_integer()) ::
              {:incident, String.t(), String.t(), keyword()}
      def retry(error_msg, details, retries \\ 2, retry_timeout \\ @default_ms)
          when retries > 0 do
        {:incident, error_msg, details, retries, retry_timeout}
      end

      @doc """
      Creates a valid incident result.
      Add a `error_msg` with a max of 666 characters to indicate the reason of the failure
      and `error_details` for a detailed error description.
      """
      @spec create_incident(String.t(), String.t()) :: {:ok, map()}
      def create_incident(error_msg, error_details) do
        {:incident, error_msg, error_details, 0, @default_ms}
      end

      @doc """
      Throws a business error in the context of a running external task by id.
      The `error_code` must be specified to identify the BPMN error handler with a
      `error_msg` with a max of 666 characters that describes the error.
      Accepts an map with atom as keys for adding process variables.
      """
      @spec throw_bpmn_error(String.t(), String.t(), map()) ::
              {:bpmn_error, String.t(), String.t(), map()}
      def throw_bpmn_error(error_code, error_msg, variables \\ %{}) do
        {:bpmn_error, error_code, error_msg, variables}
      end
    end
  end

  @impl true
  def init([{:module, module} | _] = init_args) do
    worker_id = worker_id(module)
    topics = apply(module, :register_topics, [])
    init_state = struct(__MODULE__, init_args ++ [worker_id: worker_id, topics: topics])

    {:ok, init_state, {:continue, :invoke_polling}}
  end

  def __update__(mod, attr) do
    GenServer.cast(mod, {:update, attr})
  end

  @impl true
  def handle_continue(:invoke_polling, state) do
    schedule_polling(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update, updates}, state) do
    valid_updates = Keyword.take(updates, Map.keys(state))
    attr = Keyword.merge(Map.to_list(state), valid_updates)
    {:noreply, struct(__MODULE__, attr)}
  end

  # fetch_and_lock tasks
  # invoke task
  # schedule poll
  @impl true
  def handle_info(:poll, state) do
    updated_state =
      fetch_and_lock(state)
      |> create_external_tasks(state)

    schedule_polling(state)

    {:noreply, updated_state}
  end

  @impl true
  def handle_info({reference, function_result}, state) when is_reference(reference) do
    task_id = fetch_task_id(reference, state.workload)
    Process.send(self(), {task_id, function_result}, [])
    {:noreply, state}
  end

  @impl true
  def handle_info({task_id, {:ok, variables}}, state) do
    submit(task_id, &ExternalTask.complete/2, variable_params(variables), state.worker_id)
    delete_task(task_id)

    {:noreply, state}
  end

  @impl true
  def handle_info({task_id, {:bpmn_error, err_code, err_msg, variables}}, state) do
    var_params = variable_params(variables)
    err_params = %{"errorCode" => err_code, "errorMessage" => err_msg}
    request = Map.merge(var_params, err_params)

    submit(task_id, &ExternalTask.handle_bpmn_error/2, request, state.worker_id)
    delete_task(task_id)

    {:noreply, state}
  end

  @impl true
  def handle_info({task_id, {:incident, err_msg, err_details, retries, retry_timout}}, state) do
    retries =
      state.workload
      |> get_in([task_id, :retries])
      |> Kernel.||(retries + 1)
      |> Kernel.-(1)

    workload = put_in(state.workload, [task_id, :retries], retries)

    request = %{
      "errorMessage" => err_msg,
      "errorDetails" => err_details,
      "retries" => retries,
      "retryTimeout" => retry_timout
    }

    submit(task_id, &ExternalTask.handle_failure/2, request, state.worker_id)

    if retries <= 0 do
      delete_task(task_id)
    end

    {:noreply, %{state | workload: workload}}
  end

  @impl true
  def handle_info({:delete_task, task_id}, state) do
    {:noreply, %{state | workload: Map.delete(state.workload, task_id)}}
  end

  @impl true
  def handle_info({:DOWN, _reference, :process, _function_operator_pid, :normal}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({task_id, invalid_function_result}, state) do
    incident =
      {task_id,
       {:incident, "Invalid function result", inspect(invalid_function_result), 0, @default_ms}}

    Process.send(self(), incident, [])

    {:noreply, state}
  end

  defp fetch_task_id(reference, workload) do
    Enum.find_value(workload, "", fn {task_id, task_info} ->
      task_info.task.ref == reference && task_id
    end)
  end

  defp variable_params(variables), do: %{"variables" => Variable.cast(variables)}

  defp submit(task_id, endpoint, request, worker_id) do
    endpoint.(task_id, Map.put(request, "workerId", worker_id))
    |> Cain.Endpoint.submit()
  end

  defp create_external_tasks(ex_tasks, state) do
    Enum.reduce(ex_tasks, state, fn ex_task, %{workload: workload} = state ->
      topic_name = String.to_existing_atom(ex_task["topicName"])

      {mod, func, args} = referenced_function(state.topics, topic_name)
      task = Task.async(mod, func, [ex_task] ++ args)

      ex_task_info = %{
        topic_name: topic_name,
        task: task,
        retries: ex_task["retries"]
      }

      updated_workload = Map.put(workload, ex_task["id"], ex_task_info)

      %{state | workload: updated_workload}
    end)
  end

  defp referenced_function(topics, topic_name) do
    Enum.find(topics, fn {topic, _, _} ->
      topic == topic_name
    end)
    |> elem(1)
  end

  defp fetch_and_lock(state) do
    %{
      "workerId" => state.worker_id,
      "usePriority" => state.use_priority,
      "maxTasks" => state.max_tasks,
      "topics" => Enum.map(state.topics, &create_topics(&1))
    }
    |> ExternalTask.fetch_and_lock()
    |> Endpoint.submit()
    |> case do
      {:ok, locked_tasks} -> locked_tasks
      _error -> []
    end
  end

  defp create_topics({topic, _referenced_func, opts}) do
    topic_name = Atom.to_string(topic)
    lock_duration = Keyword.get(opts, :lock_duration, @default_ms)
    %{"topicName" => topic_name, "lockDuration" => lock_duration}
  end

  defp delete_task(task_id), do: Process.send(self(), {:delete_task, task_id}, [])

  defp schedule_polling(state), do: Process.send_after(self(), :poll, state.polling_interval)

  defp worker_id(module) do
    {:ok, hostname} = :inet.gethostname()

    "#{module}<#{hostname}>"
  end
end
