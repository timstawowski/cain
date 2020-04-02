defmodule Cain.UserTask do
  @moduledoc false

  defstruct [
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

  def purify(%{} = user_task) do
    struct(__MODULE__, Cain.Response.Helper.pre_cast(user_task))
  end
end
