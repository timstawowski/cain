defmodule Cain.ProcessInstance do
  use GenServer

  defstruct [
    :business_key,
    :links,
    :suspended?,
    :ended?,
    :variables
  ]

  defmodule State do
    defstruct [
      ## meta / rest api cache ##
      :business_key,
      :case_instance_id,
      # own genserver?
      :definition_id,
      :ended?,
      :id,
      :links,
      :suspended?,
      :tenant_id,
      # :running_processes,
      variables: %{}
    ]
  end

  def cast(%State{} = state) do
    struct(__MODULE__, Map.from_struct(state))
  end

  # API

  def start_link(
        %{"businessKey" => business_key, "definitionId" => definition_id} = process_instance
      ) do
    GenServer.start_link(__MODULE__, process_instance, name: via(definition_id, business_key))
  end

  def add_variables(definition_id, business_key, variables) do
    GenServer.cast(via(definition_id, business_key), {:add_variables, variables})
  end

  # def get_activity(business_key, type) do
  #   GenServer.call(via(business_key), {:activity, type})
  # end

  def get_process_instance(definition_id, business_key) do
    GenServer.call(via(definition_id, business_key), :get_process_instance)
  end

  # def get_process_instance(nil, definition_key) do
  #   GenServer.call(server, request, timeout \\ 5000)
  #   # GenServer.call(via(business_key), :get_process_instance)
  # end

  def via(definition_id, business_key) do
    {:via, Cain.ProcessInstance.Registry,
     {:process_definition_id, definition_id, {:business_key, business_key}}}
  end

  # SERVER

  def init(process_instance) do
    # TODO handle continue
    state = Cain.Response.Helper.pre_cast(process_instance)

    {:ok, struct(State, state), {:continue, :cast}}
  end

  def handle_continue(:cast, %State{id: process_instance_id} = process_instance) do
    # activity_instance =
    Cain.Endpoint.ProcessInstance.get_activity_instance(process_instance_id)
    |> Cain.ProcessInstance.ActivityInstance.DynamicSupervisor.start_instance()

    variables =
      Cain.Endpoint.ProcessInstance.Variables.get_list(process_instance_id)
      |> Cain.Variable.parse()
      |> Enum.reduce(%{}, fn {key, value}, acc -> Map.put(acc, String.to_atom(key), value) end)

    {:noreply, %State{process_instance | variables: variables}}
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

  # def handle_call(
  #       {:activity, type},
  #       _from,
  #       %__MODULE__{activity_instance: activity_instance} = process_instances
  #     ) do
  #   filtered = ActivityInstance.filter_by_type(activity_instance, type)

  #   import IEx
  #   IEx.pry()
  #   {:reply, process_instances, process_instances}
  # end

  def handle_call(:get_process_instance, _from, process_instances) do
    {:reply, process_instances, process_instances}
  end
end
