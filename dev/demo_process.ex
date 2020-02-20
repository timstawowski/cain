defmodule DemoProcess do
  use Cain.BusinessProcess,
    definition_key: "DEMO"

  def get_current_user_task(process_instance_id) do
    get_user_tasks(process_instance_id)
    |> List.first()
    |> Cain.UserTask.cast(extend: [only: :identity_links])
  end
end
