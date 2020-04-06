defmodule Cain.ActivityInstance do
  @callback cast(String.t(), String.t()) :: struct()

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

  def cast(term), do: term
end
