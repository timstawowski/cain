defmodule Cain.ActivityInstance do
  @callback purify(map(), list()) :: struct()

  defmacro __using__(opts) do
    extensional_fields = Keyword.get(opts, :extensional_fields, [])
    Module.put_attribute(__CALLER__.module, :extensional_fields, extensional_fields)

    quote do
      @behaviour Cain.ActivityInstance

      def extend(activity, true) do
        extensional_fields = @extensional_fields
        Cain.ActivityInstance.__extend__(activity, unquote(extensional_fields))
      end

      def extend(struct, _), do: struct
    end
  end

  def __extend__(activity, extensional_fields) do
    Enum.reduce(extensional_fields, activity, fn {key, function}, acc ->
      arity =
        function
        |> :erlang.fun_info()
        |> Keyword.get(:arity)

      exension_value =
        if arity == 1 do
          function.(acc.id)
        else
          []
        end

      Map.put(acc, key, exension_value)
    end)
  end

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
  end

  def cast(
        %{
          "activityType" => "subProcess",
          "childActivityInstances" => child_activity_instances
        } = sub_process_activity
      ) do
    nested =
      child_activity_instances
      |> Enum.map(fn child_activity ->
        Cain.ActivityInstance.cast(child_activity)
      end)

    %{sub_process_activity | "childActivityInstances" => nested}
  end

  def cast(term, _opts), do: term

  def filter(child_activity_instances, attr \\ "activityId", filter \\ nil)

  def filter(child_activity_instances, attr, filter) when is_list(child_activity_instances) do
    filter(child_activity_instances, attr, filter, [])
    |> List.flatten()
  end

  defp filter([%{"childActivityInstances" => []} = head | tail], attr, filter, acc) do
    if is_nil(filter) || Map.get(head, attr) == filter do
      filter(tail, attr, filter, acc ++ [head])
    else
      filter(tail, attr, filter, acc)
    end
  end

  defp filter(
         [%{"childActivityInstances" => child_activity_instances} = head | tail],
         attr,
         filter,
         acc
       ) do
    first = Map.put(head, "childActivityInstances", [])

    [filter([first | tail], attr, filter, acc)] ++
      [filter(child_activity_instances, attr, filter, [])]
  end

  defp filter([], _attr, _filter, acc), do: acc
end
