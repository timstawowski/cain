defmodule Cain.Activity.Type.UserTask do
  use Cain.Activity,
    extentional_fields: [
      {:identity_links, &Cain.Endpoint.Task.IdentityLinks.get_list/1},
      {:form_variables, &Cain.Endpoint.Task.get_task_form_variables/1}
    ]

  defstruct [
    :assignee,
    :case_definition_id,
    :case_execution_id,
    :case_instance_id,
    :created,
    :delegation_state,
    :description,
    :due,
    :execution_id,
    :follow_up,
    :form_key,
    :form_variables,
    :id,
    :name,
    :owner,
    :parent_task_id,
    :priority,
    :process_definition_id,
    :process_instance_id,
    :suspended,
    :task_definition_key,
    :tenant_id,
    :identity_links
  ]
end
