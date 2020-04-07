defmodule Cain.UserTask do
  @moduledoc false

  use Cain.ActivityInstance,
    extensional_fields: [
      {:identity_links, &Cain.Endpoint.Task.IdentityLinks.get_list/1},
      {:form_variables, &Cain.Endpoint.Task.get_task_form_variables/2}
    ]

  defstruct [
    :id,
    :assignee,
    :created,
    :delegation_state,
    :description,
    :due,
    :follow_up,
    :form_key,
    :form_variables,
    :name,
    :owner,
    :priority,
    :suspended?,
    :identity_links
  ]

  def purify(%{} = user_task, opts \\ []) do
    extend = Keyword.get(opts, :extend, false)

    struct(__MODULE__, Cain.Response.Helper.pre_cast(user_task))
    |> extend(extend)
  end
end
