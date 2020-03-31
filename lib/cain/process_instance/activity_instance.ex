defmodule Cain.ProcessInstance.ActivityInstance do
  use GenServer

  ## meta / rest api cache ##

  defstruct [
    :activity_id,
    :activity_name,
    :activity_type,
    :child_activity_instances,
    :child_transition_instances,
    :execution_ids,
    :id,
    :incident_ids,
    :incidents,
    :name,
    :parent_activity_instance_id
  ]

  # API

  def start_link(%{"processInstanceId" => parent_process_instance_id} = parent_activity) do
    GenServer.start_link(__MODULE__, parent_activity, name: via(parent_process_instance_id))
  end

  def get(parent_activity) do
    GenServer.call(via(parent_activity), :get)
  end

  def via(parent_process_instance_id) do
    {:via, Cain.ProcessInstance.ActivityInstance.Registry,
     {:parent_process_instance_id, parent_process_instance_id}}
  end

  # SERVER

  def init(parent_activity) do
    # TODO handle continue
    instance_attr = Cain.Response.Helper.pre_cast(parent_activity)

    {:ok, struct(__MODULE__, instance_attr), {:continue, :cast}}
  end

  def handle_continue(:cast, %__MODULE__{} = parent_activity) do
    # TODO cast child processes

    {:noreply, parent_activity}
  end

  def handle_call(:get, _from, parent_activity_instance) do
    {:reply, parent_activity_instance, parent_activity_instance}
  end

  def operate_child_activity_instances(
        %__MODULE__{child_activity_instances: child_activity_instances},
        func
      ) do
    Enum.map(child_activity_instances, fn %__MODULE__{
                                            child_activity_instances:
                                              nested_child_activity_instances
                                          } = instance ->
      if Enum.empty?(nested_child_activity_instances) do
        func.(instance)
      else
        operate_child_activity_instances(instance, func)
      end
    end)
  end

  # def __operate_child_activity_instances__([], _func, operated_child_activities),
  #   do: operated_child_activities

  # def __operate_child_activity_instances__([child_activity_instance | rest], func, acc) do
  #   func_result = func.(child_activity_instance)

  #   __operate_child_activity_instances__(rest, func, acc ++ [func_result])
  # end

  def cast_activity_instance(activity_instance) do
    activity_instance = struct(__MODULE__, Cain.Response.Helper.pre_cast(activity_instance))

    cast_activity_instance(activity_instance, activity_instance.child_activity_instances)
  end

  def cast_activity_instance(%__MODULE__{} = activity_instance, []), do: activity_instance

  def cast_activity_instance(
        %__MODULE__{} = activity_instance,
        child_activity_instances
      ) do
    casted_child_activity_instances =
      Enum.map(child_activity_instances, fn child_activity_instance ->
        cast_activity_instance(child_activity_instance)
      end)

    %__MODULE__{activity_instance | child_activity_instances: casted_child_activity_instances}
  end

  defp filter_by_type(%__MODULE__{child_activity_instances: child_activity_instances}, type)
       when is_atom(type) do
    filter =
      type
      |> Atom.to_string()
      |> Macro.camelize()
      |> String.split_at(1)
      |> Tuple.to_list()
      |> List.update_at(0, &String.downcase(&1))
      |> Enum.join()

    Enum.filter(child_activity_instances, &(Map.get(&1, :activity_type) == filter))
  end
end
