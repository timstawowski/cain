defmodule Cain.ProcessInstance do
  use GenServer

  defstruct [
    :business_key,
    :links,
    :suspended?,
    :variables,
    :tokens,
    :user_tasks,
    :sub_processes,
    :__engine_state__
  ]

  defmodule State do
    defstruct [:__snapshot__, :__process_instance_id__, __timestamp__: :os.system_time()]

    defimpl Inspect, for: __MODULE__ do
      def inspect(%{__timestamp__: timestamp}, _opts) do
        "#EngineState<latest:#{timestamp}>"
      end
    end
  end

  def cast(process_instance, variables) do
    links =
      case process_instance["links"] do
        [%{"href" => link}] -> [link]
        links -> links
      end

    params =
      process_instance
      |> Cain.Response.Helper.pre_cast()
      |> Keyword.put(:variables, variables)
      |> Keyword.put(:links, links)
      |> Keyword.put(
        :__engine_state__,
        struct(State,
          __process_instance_id__: process_instance["id"]
        )
      )

    struct(__MODULE__, params)
  end

  # API
  def start_link([business_process_mod, process_instance]) do
    GenServer.start_link(__MODULE__, process_instance,
      name: via(business_process_mod, process_instance["businessKey"])
    )
  end

  def via(business_process_mod, business_key) do
    {:via, Cain.ProcessInstance.Registry, {business_process_mod, business_key}}
  end

  def add_variables(business_process_mod, business_key, variables) do
    GenServer.cast(via(business_process_mod, business_key), {:add_variables, variables})
  end

  def find(business_process_mod, business_key) do
    GenServer.call(via(business_process_mod, business_key), :find)
  end

  def get_user_tasks(business_process_mod, business_key, user_task_names) do
    GenServer.call(
      via(business_process_mod, business_key),
      {:get_activity, "activityType", "userTask", {"activityName", user_task_names}}
    )
    |> Enum.map(&Cain.UserTask.purify(&1, extend: true))
  end

  def complete_user_task(business_process_mod, business_key, task_name, variables) do
    GenServer.call(
      via(business_process_mod, business_key),
      {:complete_user_task, task_name, variables}
    )
  end

  def activate(business_process_mod, business_key) do
    GenServer.call(via(business_process_mod, business_key), :activate)
  end

  def suspend(business_process_mod, business_key) do
    GenServer.call(via(business_process_mod, business_key), :suspend)
  end

  def delete(business_process_mod, business_key, opts) do
    GenServer.call(via(business_process_mod, business_key), {:delete, opts})
  end

  # SERVER

  @impl true
  def init(process_instance) do
    {:ok, process_instance, {:continue, :cast}}
  end

  @impl true
  def handle_continue(:cast, process_instance_params) do
    variables =
      Cain.Endpoint.ProcessInstance.Variables.get_list(process_instance_params["id"])
      |> Cain.Response.Helper.variables_in_return(true)

    process_instance = cast(process_instance_params, variables)
    {:noreply, process_instance, {:continue, :init_engine_state}}
  end

  def handle_continue(:init_engine_state, process_instance) do
    update_engine_state()

    {:noreply, process_instance}
  end

  @impl true
  def handle_cast(
        {:add_variables, new_variables},
        %{__engine_state__: %{__process_instance_id__: id}, variables: variables} =
          process_instance
      ) do
    casted_variables = Cain.Variable.cast(new_variables)

    request_process_result =
      casted_variables
      |> Map.keys()
      |> Enum.map(fn var_name ->
        Cain.Endpoint.ProcessInstance.Variables.put_process_variable(%{
          id: id,
          var_name: var_name,
          var_body: casted_variables[var_name]
        })
        |> case do
          :ok ->
            :ok

          error ->
            error
        end
      end)

    state =
      Enum.all?(request_process_result, fn result -> result == :ok end)
      |> if do
        %{process_instance | variables: Map.merge(variables, new_variables)}
      else
        # reject the variables which failed on adding
        process_instance
      end

    {:noreply, state}
  end

  def handle_call(:activate, _from, %{suspended?: false} = process_instance) do
    {:reply, {:error, :already_active}, process_instance}
  end

  def handle_call(
        :activate,
        _from,
        %{__engine_state__: %State{__process_instance_id__: id}} = process_instance
      ) do
    reply = Cain.Endpoint.ProcessInstance.suspend(id, false)
    {:reply, reply, %{process_instance | suspended?: false}}
  end

  def handle_call(:suspend, _from, %{suspended?: true} = process_instance) do
    {:reply, {:error, :already_suspend}, process_instance}
  end

  def handle_call(
        :suspend,
        _from,
        %{__engine_state__: %State{__process_instance_id__: id}} = process_instance
      ) do
    reply = Cain.Endpoint.ProcessInstance.suspend(id, true)

    {:reply, reply, %{process_instance | suspended?: true}}
  end

  def handle_call(:find, _from, process_instances) do
    {:reply, process_instances, process_instances}
  end

  @impl true
  def handle_call(
        {:complete_user_task, task_name, variables},
        _from,
        process_instance
      ) do
    {reply, state} =
      find_in_snapshot("userTask", task_name, process_instance)
      |> Cain.ActivityInstance.UserTask.complete(variables)
      |> case do
        {:error, _error} = error ->
          {error, process_instance}

        casted_variables ->
          {:ok, %{process_instance | variables: casted_variables}}
      end

    update_engine_state()
    {:reply, reply, state}
  end

  def handle_call(
        {:get_activity, criteria, filter, {restrict_field, filter_values}},
        _from,
        %{
          __engine_state__: %{__snapshot__: snapshot}
        } = process_instance
      ) do
    reply =
      if !Enum.empty?(filter_values) do
        Cain.ActivityInstance.filter(snapshot, criteria, filter)
        |> Enum.filter(&(&1[restrict_field] in filter_values))
      else
        Cain.ActivityInstance.filter(snapshot, criteria, filter)
      end
      |> Enum.map(&Cain.ActivityInstance.cast/1)

    {:reply, reply, process_instance}
  end

  def handle_call(
        {:delete, _opts},
        _from,
        %{
          __engine_state__: %{__process_instance_id__: process_instance_id}
        } = process_instance
      ) do
    reply = Cain.Endpoint.ProcessInstance.delete(process_instance_id)
    {:reply, reply, process_instance}
  end

  @impl true
  def handle_info(:update_engine_state, %{__engine_state__: engine_state} = process_instance) do
    child_activities =
      Cain.Endpoint.ProcessInstance.get_activity_instance(engine_state.__process_instance_id__)
      |> Map.get("childActivityInstances")

    engine_state = %{
      engine_state
      | __snapshot__: child_activities,
        __timestamp__: :os.system_time(:millisecond)
    }

    tokens = Cain.ActivityInstance.filter(child_activities) |> Enum.count()

    user_tasks =
      Cain.ActivityInstance.filter(child_activities, "activityType", "userTask")
      |> Enum.map(&Map.get(&1, "name"))

    sub_processes =
      Cain.ActivityInstance.filter(child_activities, "activityType", "subProcess")
      |> Enum.map(&Map.get(&1, "name"))

    {:noreply,
     %{
       process_instance
       | __engine_state__: engine_state,
         tokens: tokens,
         user_tasks: user_tasks,
         sub_processes: sub_processes
     }}
  end

  defp update_engine_state do
    Process.send(self(), :update_engine_state, [])
  end

  defp find_in_snapshot(
         activity_type,
         activity_name,
         %{__engine_state__: %{__snapshot__: snapshot}}
       ) do
    Enum.find(snapshot, fn activity ->
      activity["activityName"] == activity_name and activity["activityType"] == activity_type
    end)
    |> case do
      nil ->
        {:error, :acitivity_not_found}

      activity ->
        Cain.ActivityInstance.cast(activity)
    end
  end
end
