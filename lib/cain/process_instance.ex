defmodule Cain.ProcessInstance do
  use GenServer

  defstruct [
    :__engine_state__,
    :business_key,
    :links,
    :suspended?,
    :variables,
    :tokens,
    :history,
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
      pruned = Map.drop(instance, [:__struct__, :__engine_state__])
      Inspect.Map.inspect(pruned, Code.Identifier.inspect_as_atom(__MODULE__), opts)
    end
  end

  defmodule State do
    defstruct [
      :__snapshot__,
      :__process_definition_id__,
      :__process_instance_id__,
      __timestamp__: :os.system_time()
    ]

    defimpl Inspect, for: __MODULE__ do
      import Inspect.Algebra

      def inspect(state, opts) do
        concat(["#EngineState<latest:", to_doc(state.__timestamp__, opts), ">"])
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
          __process_definition_id__: process_instance["definitionId"],
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

  @impl true
  def handle_call(
        {:process_user_task, func, task_name, args},
        _from,
        %{__engine_state__: state} = process_instance
      ) do
    user_task =
      Cain.ActivityInstance.filter(state.__snapshot__, "activityType", "userTask")
      |> Cain.ActivityInstance.filter("activityName", task_name)
      |> List.first()
      |> Cain.ActivityInstance.cast()

    {reply, state} =
      case apply(Cain.ActivityInstance.UserTask, func, [user_task] ++ args) do
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
    case Cain.Endpoint.ProcessInstance.get_activity_instance(engine_state.__process_instance_id__) do
      {:error, _instance_ended} ->
        module = engine_state.__process_definition_id__ |> String.split(":") |> List.first()
        DynamicSupervisor.terminate_child(Module.concat(Cain.BusinessProcess, module), self())
        {:stop, :ended, process_instance}

      parent_activity ->
        process_instance =
          Map.from_struct(process_instance) |> Map.drop(@activity_types) |> Map.to_list()

        child_activities = Map.get(parent_activity, "childActivityInstances")

        history =
          Cain.Endpoint.History.ActivityInstance.get_list(%{
            "processInstanceId" => engine_state.__process_instance_id__
          })
          |> Cain.ActivityInstance.History.cast()

        activity_types =
          Cain.ActivityInstance.filter(child_activities)
          |> Enum.group_by(&Map.get(&1, "activityType"))
          |> Enum.reduce([], fn {activity_type, activities}, acc ->
            key =
              activity_type
              |> Macro.underscore()
              |> String.to_existing_atom()

            value = Enum.map(activities, &Map.get(&1, "activityName"))
            [{key, value} | acc]
          end)

        new_state = struct(__MODULE__, Keyword.merge(process_instance, activity_types))

        {:noreply,
         %{
           new_state
           | __engine_state__: %{
               engine_state
               | __snapshot__: child_activities,
                 __timestamp__: :os.system_time(:millisecond)
             },
             history: history,
             tokens: Enum.count(Cain.ActivityInstance.filter(child_activities))
         }}
    end
  end

  defp update_engine_state do
    Process.send(self(), :update_engine_state, [])
  end
end
