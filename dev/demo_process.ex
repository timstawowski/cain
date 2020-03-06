defmodule DemoProcess do
  use Cain.BusinessProcess,
    definition_key: "DEMO"

  def get_current_user_task(process_instance_id) do
    user_task_list = get_user_tasks(process_instance_id)

    case List.first(user_task_list) do
      nil ->
        "No open user tasks for: #{process_instance_id}"

      user_task ->
        user_task
        |> Cain.UserTask.cast(
          # extend: :full,
          extend: [
            only: [:form_variables]
          ],
          query: [variable_names: "desired_state", deserialize_values: true]
        )
    end
  end
end
