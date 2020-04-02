defprotocol Cain.Activity do
  def count(activity_instance)
end

defimpl Cain.Activity, for: Map do
  def count(%{"childActivityInstances" => child_activity_instances}) do
    count(child_activity_instances, 0)
  end

  def count(_), do: raise("Map hast to be a valid activity instance REST response")

  def count([%{"childActivityInstances" => []} | tail], acc) do
    count(tail, acc + 1)
  end

  def count([%{"childActivityInstances" => child_activity_instances} | tail], acc) do
    count(tail, count(child_activity_instances, acc) + 1)
  end

  def count([], acc), do: acc
end

defmodule Cain.ActivityInstance do
  # alias Cain.ActivityInstance.{UserTask, SubProcess}

  @callback cast(String.t(), String.t()) :: struct()

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
    :name
  ]

  def cast(%{
        "activityType" => "userTask",
        "activityId" => activity_id,
        "processInstanceId" => process_instance_id
      }) do
    Cain.Endpoint.Task.get_list(%{
      "processInstanceId" => process_instance_id,
      "taskDefinitionKey" => activity_id
    })
    |> List.first()

    # UserTask.cast(activity_id, process_instance_id)
  end

  def cast(
        %{
          "activityType" => "subProcess",
          "childActivityInstances" => child_activity_instances
          # "name" => name
        } = sub_process_activity
      ) do
    nested =
      child_activity_instances
      |> Enum.map(fn child_activity ->
        Cain.ActivityInstance.cast(child_activity)
      end)

    %{sub_process_activity | "childActivityInstances" => nested}
    # SubProcess.cast(name, child_activity_instances)
  end

  def cast(term), do: term

  def map_by_type([%{"activityType" => activity_type} = head | tail], filter)
      when activity_type == filter do
    [head | map_by_type(tail, filter)]
  end

  def map_by_type(
        [
          %{"activityType" => "subProcess", "childActivityInstances" => child_activity_instances}
          | _tail
        ],
        filter
      ) do
    map_by_type(child_activity_instances, filter)
  end

  def map_by_type([_head | tail], filter) do
    map_by_type(tail, filter)
  end

  def map_by_type([], _filter), do: []

  # def cast(
  #       %{
  #         "activityType" => activity_type,
  #         "activityId" => activity_id,
  #         "childActivityInstances" => child_activity_instances,
  #         "parentActivityInstanceId" => process_instance_id
  #       } = activity_instance
  #     ) do
  #   activity_type_mod = Module.concat(Cain, Macro.camelize(activity_type))
  #   activity_type_mod_state = Module.concat(activity_type_mod, "State")

  #   if function_exported?(activity_type_mod_state, :cast, 2) do
  #     apply(activity_type_mod_state, :cast, [activity_id, process_instance_id])
  #   else
  #     childs =
  #       Enum.map(child_activity_instances, fn child ->
  #         cast(Map.put(child, "parentActivityInstanceId", process_instance_id))
  #       end)

  #     Map.put(activity_instance, "childActivityInstances", childs)
  #   end
  # end

  # defmacro __using__(opts) do
  #   extentional_fields = Keyword.get(opts, :extentional_fields)

  #   quote do
  #     def cast(params, opts \\ [])

  #     def cast(params, []) do
  #       struct(__MODULE__, pre_cast(params))
  #     end

  #     def cast(params, opts) do
  #       extend = Keyword.get(opts, :extend)

  #       struct(__MODULE__, pre_cast(params))
  #       |> Cain.Activity.__extend__(unquote(extentional_fields), extend)
  #     end

  #     def get_extentional_fields, do: Keyword.keys(unquote(extentional_fields))
  #   end
  # end

  # def __extend__(activity, _extentional_fields, nil) do
  #   activity
  # end

  # def __extend__(activity, extentional_fields, :full) do
  #   __extend__(activity, extentional_fields, only: Keyword.keys(extentional_fields))
  # end

  # def __extend__(activity, extentional_fields, only: only) do
  #   extentions =
  #     cond do
  #       is_atom(only) ->
  #         Keyword.take(extentional_fields, [only])

  #       is_list(only) && Keyword.keyword?(only) ->
  #         Keyword.take(extentional_fields, Keyword.keys(only))

  #       is_list(only) ->
  #         Keyword.take(extentional_fields, only)
  #     end

  #   Enum.reduce(extentions, activity, fn {field, func}, activity ->
  #     func_info = Function.info(func)

  #     Map.put(
  #       activity,
  #       field,
  #       if func_info[:arity] == 1 do
  #         func.(activity.id)
  #       else
  #         func.(
  #           activity.id,
  #           pre_cast_query(only[field])
  #         )
  #         |> variables_in_return(true)
  #       end
  #     )
  #   end)
  # end
end
