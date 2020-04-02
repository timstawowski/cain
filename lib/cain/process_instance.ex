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
    defstruct [:__snapshot__, :__timestamp__, :__process_instance_id__]

    defimpl Inspect, for: __MODULE__ do
      def inspect(%{__timestamp__: timestamp}, _opts) do
        "#EngineState<latest:#{timestamp}>"
      end
    end
  end

  def cast(process_instance, engine_state, process_instance_id, variables) do
    child_activities = Map.get(engine_state, "childActivityInstances")

    user_tasks =
      Cain.ActivityInstance.map_by_type(child_activities, "userTask")
      |> Enum.map(&Map.get(&1, "name"))

    sub_processes =
      Cain.ActivityInstance.map_by_type(child_activities, "subProcess")
      |> Enum.map(&Map.get(&1, "name"))

    links =
      case process_instance["links"] do
        [%{"href" => link}] -> [link]
        links -> links
      end

    params =
      process_instance
      |> Cain.Response.Helper.pre_cast()
      |> Keyword.put(:variables, variables)
      |> Keyword.put(:user_tasks, user_tasks)
      |> Keyword.put(:sub_processes, sub_processes)
      |> Keyword.put(:links, links)
      |> Keyword.put(:tokens, Cain.Activity.count(engine_state))
      |> Keyword.put(
        :__engine_state__,
        struct(State,
          __snapshot__: child_activities,
          __timestamp__: :os.system_time(:millisecond),
          __process_instance_id__: process_instance_id
        )
      )

    struct(__MODULE__, params)
  end

  # API

  def start_link(
        %{"id" => process_instance_id, "definitionId" => definition_id} = process_instance
      ) do
    GenServer.start_link(__MODULE__, process_instance,
      name: via(definition_id, process_instance_id)
    )
  end

  def add_variables(definition_id, process_instance_id, variables) do
    GenServer.call(via(definition_id, process_instance_id), {:add_variables, variables})
  end

  def get_process_instance(definition_id, process_instance_id) do
    GenServer.call(via(definition_id, process_instance_id), :get_process_instance)
  end

  def via(definition_id, process_instance_id) do
    {:via, Cain.ProcessInstance.Registry,
     {:process_definition_id, definition_id, {:process_instance_id, process_instance_id}}}
  end

  # SERVER

  def init(process_instance) do
    {:ok, process_instance, {:continue, :cast}}
  end

  def handle_continue(
        :cast,
        %{"id" => process_instance_id} = process_instance_params
      ) do
    engine_state = Cain.Endpoint.ProcessInstance.get_activity_instance(process_instance_id)

    variables =
      Cain.Endpoint.ProcessInstance.Variables.get_list(process_instance_id)
      |> Cain.Variable.parse()

    # |> Enum.reduce(%{}, fn {key, value}, acc -> Map.put(acc, String.to_atom(key), value) end)

    process_instance = cast(process_instance_params, engine_state, process_instance_id, variables)

    {:noreply, process_instance}
  end

  def handle_call(
        {:add_variables, new_variables},
        _from,
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

    {:reply, state, state}
  end

  def handle_call(:get_process_instance, _from, process_instances) do
    {:reply, process_instances, process_instances}
  end
end
