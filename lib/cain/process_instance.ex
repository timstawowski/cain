defmodule Cain.ProcessInstance do
  use GenServer

  defstruct [
    :business_key,
    :case_instance_id,
    :definition_id,
    :ended,
    :id,
    :links,
    :suspended,
    :tenant_id,
    :variables,
    :activity_instance
  ]

  defmodule ActivityInstance do
    defstruct [
      :activity_id,
      :activity_name,
      :activity_type,
      :child_activity_instances,
      :child_transition_instances,
      :execution_ids,
      :id,
      :incident_ids,
      :name,
      :parent_activity_instance_id,
      :process_definition_id,
      :process_instance_id
    ]

    def cast(params) do
      struct(__MODULE__, Cain.ProcessInstance.format_response(params))
    end
  end

  # API

  def create({:ok, process_instance_rest_response}) when is_map(process_instance_rest_response) do
    GenServer.start_link(__MODULE__, process_instance_rest_response)
  end

  def add_message(pid, process_instance) do
    GenServer.cast(pid, {:init_instance, process_instance})
  end

  def get_variable(pid, variable_name) do
    GenServer.call(pid, {:variable, variable_name})
  end

  def get_instance(pid) do
    GenServer.call(pid, :get_instance)
  end

  def get_variables(pid) do
    GenServer.call(pid, :variables)
  end

  # SERVER

  def init(process_instance) do
    process_instance = process_instance

    {:ok, cast(process_instance), {:continue, :init}}
  end

  def handle_continue(:init, process_instance) do
    {:ok, activity_instance} =
      Cain.Endpoint.ProcessInstance.get_activity_instance(process_instance.id)

    init_state = %__MODULE__{
      process_instance
      | activity_instance: ActivityInstance.cast(activity_instance)
    }

    {:noreply, init_state}
  end

  def handle_cast({:add_message, new_message}, messages) do
    {:noreply, [new_message | messages]}
  end

  def handle_call(:get_instance, _from, process_instance) do
    {:reply, process_instance, process_instance}
  end

  def handle_call(:variables, _from, process_instance) do
    {:reply, process_instance.variables, process_instance}
  end

  def handle_call({:variable, variable_name}, _from, process_instance) do
    {:reply, Map.get(process_instance.variables, variable_name, :enoent), process_instance}
  end

  defp cast(params) do
    struct(__MODULE__, format_response(params))
  end

  def format_response(params) do
    params
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      value =
        cond do
          key == "variables" ->
            Cain.Variable.parse(value)

          key == "childActivityInstances" ->
            Enum.map(value, &Cain.ProcessInstance.ActivityInstance.cast(&1))

          true ->
            value
        end

      Map.put(acc, Macro.underscore(key) |> String.to_existing_atom(), value)
    end)
  end
end
