defmodule Cain.ExternalWorker do
  @moduledoc """
  Helper to handle external tasks with the Camunda-BPM.
  """

  use GenServer

  alias Cain.Endpoint
  alias Cain.Variable

  alias __MODULE__.ExternalTask

  require Logger

  @typedoc """
  Name of the topic name in the BPMN-Model to be referenced.
  """
  @type ref_topic_name :: atom

  @typedoc """
  MFA of the actual function which should be applied.
  """
  @type work_to_be_processed :: {module, atom, keyword}

  @typedoc """
  Time in milliseconds to be locked for a `Cain.ExternalWorker` process while fetching a topic.
  """
  @type lock_duration :: [lock_duration: pos_integer]

  @typedoc """
  Reference format to indicate the referenced.
  """
  @type topic :: {ref_topic_name, work_to_be_processed, lock_duration}
  @type topics :: list(topic)

  @type varibles :: %{atom => any}

  @type error_code :: binary
  @type error_message :: binary
  @type error_details :: binary

  @type retries :: pos_integer
  @type retry_timout :: pos_integer

  @typedoc """
  Valid return values for `Cain.ExternalWorker` computing a referenced topic function.
  """
  @type success :: {:ok, varibles()}
  @type retry :: {:incident, error_message(), error_details(), retries(), retry_timout()}
  @type incident :: {:incident, error_message(), error_details(), 0, retry_timout()}
  @type bpmn_error :: {:bpmn_error, error_code(), error_message(), varibles()}

  @callback register_topics() :: topics

  defstruct [
    :worker_id,
    :module,
    :topics,
    max_tasks: 3,
    use_priority: false,
    polling_interval: 3000,
    workload: %{}
  ]

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
      @spec success(%{atom() => any()}) :: Cain.ExternalWorker.success()
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
              Cain.ExternalWorker.retry()
      def retry(error_msg, error_details \\ "", retries \\ 2, retry_timeout \\ 3000)
          when retries > 0 do
        {:incident, error_msg, error_details, retries, retry_timeout}
      end

      @doc """
      Creates a valid incident result.
      Add a `error_msg` with a max of 666 characters to indicate the reason of the failure
      and `error_details` for a detailed error description.
      """
      @spec create_incident(String.t(), String.t()) :: Cain.ExternalWorker.incident()
      def create_incident(error_msg, error_details \\ "") do
        {:incident, error_msg, error_details, 0, 3000}
      end

      @doc """
      Throws a business error in the context of a running external task by id.
      The `error_code` must be specified to identify the BPMN error handler with a
      `error_msg` with a max of 666 characters that describes the error.
      Accepts an map with atom as keys for adding process variables.
      """
      @spec throw_bpmn_error(String.t(), String.t(), map()) :: Cain.ExternalWorker.bpmn_error()
      def throw_bpmn_error(error_code, error_msg, variables \\ %{}) do
        {:bpmn_error, error_code, error_msg, variables}
      end
    end
  end

  @impl true
  def init([{:module, module} | init_args]) do
    worker_id = worker_id(module)
    topics = apply(module, :register_topics, [])
    init_state = struct(__MODULE__, init_args ++ [worker_id: worker_id, topics: topics])

    {:ok, init_state, {:continue, :invoke_polling}}
  end

  def __update__(mod, attr) do
    GenServer.cast(mod, {:update, attr})
  end

  @impl true
  def handle_cast({:update, updates}, state) do
    valid_updates = Keyword.take(updates, Map.keys(state))
    attr = Keyword.merge(Map.to_list(state), valid_updates)
    {:noreply, struct(__MODULE__, attr)}
  end

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
    {:noreply, state, {:continue, {task_id, function_result}}}
  end

  @impl true
  def handle_info({task_id, invalid_function_result}, state) do
    incident = {:incident, "Invalid function result", inspect(invalid_function_result), 0, 3000}
    {:noreply, state, {:continue, {task_id, incident}}}
  end

  @impl true
  def handle_info({:DOWN, reference, :process, _pid, :normal}, state) do
    task_id = fetch_task_id(reference, state.workload)
    external_task = state.workload[task_id]

    workload =
      if external_task.status == :processed,
        do: Map.delete(state.workload, task_id),
        else: state.workload

    {:noreply, %{state | workload: workload}}
  end

  @impl true
  def handle_continue(:invoke_polling, state) do
    schedule_polling(state)
    {:noreply, state}
  end

  @impl true
  def handle_continue({nil, function_result}, state) do
    type = elem(function_result, 0)

    Logger.warn(
      "Recieved invalid 'external_task_id' with type '#{inspect(type)}', function result will be ignored."
    )

    {:noreply, state}
  end

  @impl true
  def handle_continue({task_id, {:ok, variables}}, state) do
    request_body = %{"workerId" => state.worker_id, "variables" => Variable.cast(variables)}

    Endpoint.ExternalTask.complete(task_id, request_body)
    |> Endpoint.submit()

    workload = mark_external_task_as_processed(task_id, state.workload)

    {:noreply, %{state | workload: workload}}
  end

  @impl true
  def handle_continue({task_id, {:bpmn_error, err_code, err_msg, variables}}, state) do
    request_body = %{
      "workerId" => state.worker_id,
      "errorCode" => err_code,
      "errorMessage" => err_msg,
      "variables" => Variable.cast(variables)
    }

    Endpoint.ExternalTask.handle_bpmn_error(task_id, request_body)
    |> Endpoint.submit()

    workload = mark_external_task_as_processed(task_id, state.workload)
    {:noreply, %{state | workload: workload}}
  end

  @impl true
  def handle_continue({task_id, {:incident, err_msg, err_details, retries, retry_timout}}, state) do
    current_retries = calculate_retries(state.workload, task_id, retries)

    request_body = %{
      "workerId" => state.worker_id,
      "errorMessage" => err_msg,
      "errorDetails" => err_details,
      "retries" => current_retries,
      "retryTimeout" => retry_timout
    }

    Endpoint.ExternalTask.handle_failure(task_id, request_body)
    |> Endpoint.submit()

    workload = mark_external_task_as_processed(task_id, state.workload)
    {:noreply, %{state | workload: workload}}
  end

  defp fetch_task_id(reference, workload) do
    Enum.find_value(workload, fn {task_id, task_info} ->
      task_info.task.ref == reference && task_id
    end)
  end

  defp calculate_retries(workload, task_id, retries) do
    external_task = workload[task_id]

    external_task.retries
    |> Kernel.||(retries + 1)
    |> Kernel.-(1)
  end

  defp create_external_tasks(ex_tasks, state) do
    Enum.reduce(ex_tasks, state, fn ex_task, %{workload: workload} = state ->
      external_task = apply_external_task(state.topics, ex_task)
      updated_workload = Map.put(workload, ex_task["id"], external_task)

      %{state | workload: updated_workload}
    end)
  end

  defp fetch_and_lock(state) do
    %{
      "workerId" => state.worker_id,
      "usePriority" => state.use_priority,
      "maxTasks" => state.max_tasks,
      "topics" => Enum.map(state.topics, &create_topics(&1))
    }
    |> Endpoint.ExternalTask.fetch_and_lock()
    |> Endpoint.submit()
    |> case do
      {:ok, locked_tasks} -> locked_tasks
      _error -> []
    end
  end

  defp apply_external_task(topics, external_task) do
    topic_name = String.to_existing_atom(external_task["topicName"])
    parsed_vars = Map.update!(external_task, "variables", &Variable.parse/1)

    {mod, func, args} = referenced_function(topics, topic_name)
    task = Task.async(mod, func, [parsed_vars] ++ args)

    %ExternalTask{topic_name: topic_name, task: task, retries: external_task["retries"]}
  end

  defp referenced_function(topics, topic_name),
    do: Enum.find(topics, &(elem(&1, 0) == topic_name)) |> elem(1)

  defp create_topics({topic, _referenced_func, opts}) do
    topic_name = Atom.to_string(topic)
    lock_duration = Keyword.get(opts, :lock_duration, 3000)
    %{"topicName" => topic_name, "lockDuration" => lock_duration}
  end

  defp mark_external_task_as_processed(task_id, workload),
    do: put_in(workload, [task_id], ExternalTask.mark_as_processed(workload[task_id]))

  defp schedule_polling(state), do: Process.send_after(self(), :poll, state.polling_interval)

  defp worker_id(module) do
    {:ok, hostname} = :inet.gethostname()

    "#{module}<#{hostname}>"
  end
end
