defmodule Cain.ProcessInstance do
  use GenServer

  import Cain.ActivityInstance

  alias Cain.ActivityInstance

  defstruct [
    :__engine_state__,
    :__timeout__,
    :business_key,
    :links,
    :suspended?,
    :variables,
    :tokens,
    :history,
    :version,
    messages: [],
    user_task: [],
    service_task: [],
    receive_task: [],
    sub_process: []
  ]

  @activity_types [
    :user_task,
    :service_task,
    :receive_task,
    :sub_process
  ]

  defimpl Inspect, for: __MODULE__ do
    def inspect(instance, opts) do
      pruned = Map.drop(instance, [:__struct__, :__engine_state__, :__timeout__])
      Inspect.Map.inspect(pruned, Code.Identifier.inspect_as_atom(__MODULE__), opts)
    end
  end

  defmodule State do
    defstruct [
      :__activities__,
      :__process_definition_id__,
      :__process_instance_id__,
      :__execution_ids__,
      :__events__,
      __timestamp__: :os.system_time()
    ]

    defimpl Inspect, for: __MODULE__ do
      import Inspect.Algebra

      def inspect(state, opts) do
        concat(["#EngineState<latest:", to_doc(state.__timestamp__, opts), ">"])
      end
    end
  end

  def cast(process_instance, variables, timeout) do
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
      |> Keyword.put(:__timeout__, {timeout, schedule_timeout(timeout)})
      |> Keyword.put(
        :__engine_state__,
        struct(State,
          __process_definition_id__: process_instance["definitionId"],
          __process_instance_id__: process_instance["id"]
        )
      )

    struct(__MODULE__, params)
  end

  # API
  def start_link([business_process_mod, process_instance, message_names, instance_timeout]) do
    GenServer.start_link(__MODULE__, {process_instance, message_names, instance_timeout},
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

  def update_state(business_process_mod, business_key) do
    GenServer.cast(via(business_process_mod, business_key), :update_engine_state)
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
      {:process_user_task, :complete, task_name, [variables]}
    )
  end

  def claim_user_task(business_process_mod, business_key, task_name, assignee) do
    GenServer.call(
      via(business_process_mod, business_key),
      {:process_user_task, :claim, task_name, [assignee]}
    )
  end

  def unclaim_user_task(business_process_mod, business_key, task_name) do
    GenServer.call(
      via(business_process_mod, business_key),
      {:process_user_task, :unclaim, task_name, []}
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
  def init(init_args) do
    {:ok, init_args, {:continue, :cast}}
  end

  @impl true
  def handle_continue(:cast, {process_instance_params, message_names, instance_timeout}) do
    variables =
      Cain.Endpoint.ProcessInstance.Variables.get_list(process_instance_params["id"])
      |> Cain.Response.Helper.variables_in_return(true)

    process_instance = cast(process_instance_params, variables, instance_timeout)

    {:noreply, {process_instance, message_names}, {:continue, :cast_message_events}}
  end

  def handle_continue(:cast_message_events, {process_instance, message_names}) do
    message_events =
      Enum.reduce(message_names, [], fn message_name, acc ->
        case Cain.Endpoint.Execution.get_list(%{
               "processInstanceId" => process_instance.__engine_state__.__process_instance_id__,
               "messageEventSubscriptionName" => message_name
             }) do
          [single_execution] ->
            message_event =
              Cain.Endpoint.Execution.MessageEventSubscription.get(
                single_execution["id"],
                message_name
              )

            [message_event | acc]

          [] ->
            acc
        end
      end)

    {:noreply,
     %{
       process_instance
       | __engine_state__: Map.put(process_instance.__engine_state__, :__events__, message_events)
     }, {:continue, :init_engine_state}}
  end

  def handle_continue(:init_engine_state, process_instance) do
    update_engine_state()

    {:noreply, process_instance}
  end

  @impl true
  def handle_cast(:update_engine_state, process_instance) do
    update_engine_state()
    {:noreply, process_instance}
  end

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

  @impl true
  def handle_call(
        {:process_user_task, func, task_name, args},
        _from,
        %{__engine_state__: state, user_task: user_task} = process_instance
      ) do
    if Enum.member?(user_task, task_name) do
      user_task =
        filter(state.__activities__, "activityType", "userTask")
        |> filter("activityName", task_name)
        |> List.first()
        |> ActivityInstance.cast()

      {reply, state} =
        case apply(ActivityInstance.UserTask, func, [user_task] ++ args) do
          :ok ->
            update_engine_state()

            {:ok, process_instance}

          variables when is_map(variables) ->
            update_engine_state()

            {:ok, %{process_instance | variables: variables}}

          error ->
            {error, process_instance}
        end

      {:reply, reply, state}
    else
      {:reply, {:error, :unknown_task}, process_instance}
    end
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

  def handle_call(
        {:get_activity, criteria, filter, {restrict_field, filter_values}},
        _from,
        %{
          __engine_state__: %{__activities__: snapshot, __events__: events}
        } = process_instance
      ) do
    reply =
      if !Enum.empty?(filter_values) do
        filter(snapshot, criteria, filter)
        |> Enum.filter(&(&1[restrict_field] in filter_values))
      else
        filter(snapshot, criteria, filter)
      end
      |> Enum.map(fn activity ->
        boundary_events =
          Enum.filter(events, fn %{"executionId" => execution_id} ->
            Enum.member?(activity["executionIds"], execution_id)
          end)

        {ActivityInstance.cast(activity), boundary_events}
      end)

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
  def handle_info(
        :update_engine_state,
        %{__engine_state__: engine_state, __timeout__: curent_timeout} = process_instance
      ) do
    case Cain.Endpoint.ProcessInstance.get_activity_instance(engine_state.__process_instance_id__) do
      {:error, _instance_ended} ->
        module = engine_state.__process_definition_id__ |> String.split(":") |> List.first()
        DynamicSupervisor.terminate_child(Module.concat(Cain.BusinessProcess, module), self())
        {:stop, :ended, process_instance}

      parent_activity ->
        updated_state =
          Map.from_struct(process_instance) |> Map.drop(@activity_types) |> Map.to_list()

        child_activities = Map.get(parent_activity, "childActivityInstances")
        filtered = filter(child_activities)

        history =
          Cain.Endpoint.History.ActivityInstance.get_list(%{
            "processInstanceId" => engine_state.__process_instance_id__
          })
          |> ActivityInstance.History.cast()

        activity_types =
          filtered
          |> Enum.group_by(&Map.get(&1, "activityType"))
          |> Enum.reduce([], fn {activity_type, activities}, acc ->
            key =
              activity_type
              |> Macro.underscore()
              |> String.to_existing_atom()

            value = Enum.map(activities, &Map.get(&1, "activityName"))
            [{key, value} | acc]
          end)

        activity_execution_ids =
          Enum.map(filtered, &Map.get(&1, "executionIds"))
          |> List.flatten()
          |> Enum.uniq()

        messages =
          Enum.reduce(engine_state.__events__, [], fn %{"eventType" => "message"} = event, acc ->
            if Enum.member?(activity_execution_ids, event["executionId"]) do
              acc
            else
              [event["eventName"] | acc]
            end
          end)

        new_state = struct(__MODULE__, Keyword.merge(updated_state, activity_types))

        {:noreply,
         %{
           new_state
           | __timeout__: update_timeout(curent_timeout),
             __engine_state__: %{
               engine_state
               | __activities__: child_activities,
                 __execution_ids__: parent_activity["executionIds"],
                 __timestamp__: :os.system_time(:millisecond)
             },
             messages: messages,
             history: history,
             version: version(parent_activity["processDefinitionId"]),
             tokens: Enum.count(parent_activity["executionIds"])
         }}
    end
  end

  def handle_info(:timeout, process_instance) do
    module =
      process_instance.__engine_state__.__process_definition_id__
      |> String.split(":")
      |> List.first()

    DynamicSupervisor.terminate_child(Module.concat(Cain.BusinessProcess, module), self())
    {:stop, :timeout, process_instance}
  end

  defp update_engine_state do
    Process.send(self(), :update_engine_state, [])
  end

  def update_timeout({timeout, timer_ref}) do
    Process.cancel_timer(timer_ref)
    {timeout, schedule_timeout(timeout)}
  end

  def schedule_timeout(timeout) do
    Process.send_after(self(), :timeout, timeout)
  end

  defp version(process_defintion_id) when is_binary(process_defintion_id) do
    version(String.split(process_defintion_id, ":"))
  end

  defp version([_process_defintion_key, version, _process_defintion_id]),
    do: String.to_integer(version)

  defp version(_), do: {:key, :definiton_key}
end
