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
          extend: :full
          # extend: [only: :identity_links]
          # extend: [only: [:form_variables, :identity_links]]
          # extend: [only: [form_variables: [variable_names: "following_status", deserialize_values: false]]]
        )
    end
  end
end
