defprotocol Cain.Activity do
  def filter(child_activity_instances, attr \\ "activityId", filter \\ nil)
end

defimpl Cain.Activity, for: List do
  def filter(child_activity_instances, attr, filter) do
    filter(child_activity_instances, attr, filter, [])
    |> List.flatten()
  end

  def filter([%{"childActivityInstances" => []} = head | tail], attr, filter, acc) do
    if is_nil(filter) || Map.get(head, attr) == filter do
      filter(tail, attr, filter, acc ++ [head])
    else
      filter(tail, attr, filter, acc)
    end
  end

  def filter(
        [%{"childActivityInstances" => child_activity_instances} = head | tail],
        attr,
        filter,
        acc
      ) do
    nested = filter(child_activity_instances, attr, filter, acc) |> List.flatten()

    if is_nil(filter) || Map.get(head, attr) == filter do
      filter(tail, attr, filter, acc ++ [head] ++ [nested])
    else
      filter(tail, attr, filter, acc ++ [nested])
    end
  end

  def filter([], _attr, _filter, acc), do: acc
end
