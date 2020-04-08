defmodule Cain.UserTask do
  @moduledoc false

  use Cain.ActivityInstance,
    extensional_fields: [
      {:identity_links, &Cain.Endpoint.Task.IdentityLinks.get_list/1},
      {:form_variables, &Cain.Endpoint.Task.get_task_form_variables/2}
    ]

  # TODO: Move id back to activity instance
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
    :identity_links,
    boundary_events: []
  ]

  def purify({%{} = user_task, boundary_events}, opts \\ []) do
    extend = Keyword.get(opts, :extend, false)
    params = Cain.Response.Helper.pre_cast(user_task)
    boundaries = Enum.map(boundary_events, &Cain.Event.cast/1)

    struct(
      __MODULE__,
      params ++ [boundary_events: boundaries]
    )
    |> extend(extend)
  end
end
