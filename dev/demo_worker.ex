defmodule DemoWorker do
  # use Cain.ExternalWorker,
  #   topic: "migrate"

  def migrate(
        %{
          "processDefinitionId" => process_definition_id,
          "processInstanceId" => process_instance_id
        } = payload,
        args
      ) do
    # {:ok, super_activity} =
    #   Cain.Endpoint.ProcessInstance.get_activity_instance(process_instance_id)
    #   |> Cain.Endpoint.submit()

    # Cain.Endpoint.Modification.execute(%{
    #   "processDefinitionId" => process_definition_id,
    #   "instructions" => [
    #     %{
    #       "type" => "startBeforeActivity",
    #       "activityId" => "manual-work"
    #     },
    #     %{
    #       "type" => "cancel",
    #       "activityId" => get_activity_id(super_activity),
    #       "cancelCurrentActiveActivityInstances" => true
    #     }
    #   ],
    #   "processInstanceIds" => [process_instance_id],
    #   "skipCustomListeners" => false,
    #   "annotation" => "Correct EOC."
    # })
    # |> Cain.Endpoint.submit()
    IO.inspect(payload, label: :IN_FUNCTION)
    :ok
    # IO.inspect(args, label: :args)
    # :ok
  end

  def instate(payload) do
    IO.inspect(payload, label: :payload)
    :ok
  end

  defp get_activity_id(%{
         "childActivityInstances" => [
           %{"activityName" => "migrate"},
           %{"activityId" => activity_id}
         ]
       }) do
    activity_id
  end
end
