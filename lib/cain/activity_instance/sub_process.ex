defmodule Cain.ActivityInstance.SubProcess do
  # use Cain.ActivityInstance,
  #   extentional_fields: [
  #     {:identity_links, &Cain.Endpoint.Task.IdentityLinks.get_list/1},
  #     {:form_variables, &Cain.Endpoint.Task.get_task_form_variables/2}
  #   ]
  @behaviour Cain.ActivityInstance

  defstruct [
    :name,
    :sub_activities
  ]

  def cast(name, child_activity_instances) do
    sub_activities =
      child_activity_instances
      |> Enum.map(fn child_activity ->
        Cain.ActivityInstance.cast(child_activity)
      end)

    struct(__MODULE__, name: name, sub_activities: sub_activities)
  end
end
