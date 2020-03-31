defmodule Cain.ProcessInstance do
  use GenServer

  alias Cain.ProcessInstance.ActivityInstance

  defstruct [
    :business_key,
    :links,
    :suspended?,
    :ended?,
    :variables,
    :current_activities
  ]

  defmodule State do
    defstruct [
      ## meta / rest api cache ##
      :business_key,
      :case_instance_id,
      :definition_id,
      :ended?,
      :id,
      :links,
      :suspended?,
      :tenant_id,
      :activity_instance,
      variables: %{}
    ]
  end

  def cast(
        %State{
          activity_instance: %ActivityInstance{child_activity_instances: child_activity_instances}
        } = state
      ) do
    current_activities =
      Enum.map(child_activity_instances, fn child_activity ->
        try do
          Cain.ActivityByType.get(child_activity)
        rescue
          _ -> %{name: child_activity.activity_type}
        end
      end)

    params =
      state
      |> Map.from_struct()
      |> Map.put(:current_activities, current_activities)

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
    GenServer.cast(via(definition_id, process_instance_id), {:add_variables, variables})
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
    # TODO handle continue
    state = Cain.Response.Helper.pre_cast(process_instance)

    {:ok, struct(State, state), {:continue, :cast}}
  end

  def handle_continue(:cast, %State{id: process_instance_id} = process_instance) do
    activity_instance =
      Cain.Endpoint.ProcessInstance.get_activity_instance(process_instance_id)
      |> Cain.ProcessInstance.ActivityInstance.cast_activity_instance()

    variables =
      Cain.Endpoint.ProcessInstance.Variables.get_list(process_instance_id)
      |> Cain.Variable.parse()
      |> Enum.reduce(%{}, fn {key, value}, acc -> Map.put(acc, String.to_atom(key), value) end)

    {:noreply,
     %State{process_instance | activity_instance: activity_instance, variables: variables}}
  end

  def handle_cast({:add_variables, variables}, %{id: id} = process_instances)
      when is_map(variables) do
    casted_variables = Cain.Variable.cast(variables)

    casted_variables
    |> Map.keys()
    |> Enum.each(fn var_name ->
      Cain.Endpoint.ProcessInstance.Variables.put_process_variable(%{
        id: id,
        var_name: var_name,
        var_body: casted_variables[var_name]
      })
    end)

    {:noreply, Map.put(process_instances, :variables, variables)}
  end

  def handle_call(:get_process_instance, _from, process_instances) do
    {:reply, process_instances, process_instances}
  end
end
