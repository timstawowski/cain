defmodule Cain.UserTask do
  @moduledoc false
  use Cain.Activity,
    extentional_fields: [
      {:identity_links, &Cain.Endpoint.Task.IdentityLinks.get_list/1},
      {:form_variables, &Cain.Endpoint.Task.get_task_form_variables/2}
    ]

  alias Cain.{Endpoint.Task, UserTask, Variable}

  @type user_task() :: %UserTask{}

  @enforce_keys [
    :created,
    :execution_id,
    :id,
    :name,
    :process_definition_id,
    :process_instance_id,
    :suspended?,
    :task_definition_key
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
    :suspended?,
    :task_definition_key,
    :tenant_id,
    :identity_links
  ]

  @doc """
  Changes the assignee of a task to a specific user.
  """
  # TODO: Add validation on candidates
  @spec claim(UserTask.t(), String.t()) ::
          :ok | {:already_claimed_by, String.t()} | {:error, String.t()}
  def claim(%__MODULE__{assignee: assignee}, _user_id) when not is_nil(assignee) do
    {:already_claimed_by, assignee}
  end

  def claim(%__MODULE__{id: id, assignee: nil}, user_id) do
    Task.claim(id, user_id)
  end

  @doc """
  Resets a task’s assignee if a assginee is set, otherwise returns `:not_claimed`
  """
  @spec unclaim(UserTask.t()) :: :ok | :not_claimed | {:error, String.t()}
  def unclaim(%__MODULE__{assignee: nil}) do
    :not_claimed
  end

  def unclaim(%__MODULE__{id: id}) do
    Task.unclaim(id)
  end

  @doc """
  Changes the assignee of a task to a specific user.

  The difference with the Claim Task method is that this method does not check if the task already has a user assigned to it.
  """
  @spec set_assignee(UserTask.t(), String.t()) :: :ok | {:error, String.t()}
  def set_assignee(%__MODULE__{id: id}, user_id) do
    Task.set_assignee(id, user_id)
  end

  @spec delegate(UserTask.t(), String.t()) :: :ok | {:error, String.t()}
  def delegate(%__MODULE__{id: id}, user_id) do
    Task.delegate(id, user_id)
  end

  @spec resolve(UserTask.t(), Variable.t()) :: :ok | {:error, String.t()}
  def resolve(%__MODULE__{id: id}, variables) do
    Task.resolve(id, variables)
  end

  @spec submit_form(UserTask.t(), Variable.t(), list()) :: :ok | {:error, String.t()}
  def submit_form(%__MODULE__{id: task_id}, params, opts) do
    with_variables_in_return? = Keyword.get(opts, :with_variables_in_return?, true)

    Task.submit_form(task_id, %{
      "variables" => Variable.cast(params),
      "withVariablesInReturn" => with_variables_in_return?
    })
    |> Cain.Response.Helper.variables_in_return(with_variables_in_return?)
  end

  @doc """
  Completes a task and updates process variables.

  To indicate whether the response should contain the process variables or not `with_variables_in_return?` can be set to `true` default is false.
  """
  @spec complete(UserTask.t(), Variable.t(), list()) ::
          :ok | Variable.t() | {:error, String.t()}
  def complete(%__MODULE__{id: task_id}, params \\ %{}, opts \\ []) do
    with_variables_in_return? = Keyword.get(opts, :with_variables_in_return?, true)

    Task.complete(task_id, %{
      "variables" => Variable.cast(params),
      "withVariablesInReturn" => with_variables_in_return?
    })
    |> Cain.Response.Helper.variables_in_return(with_variables_in_return?)
  end

  @doc """
  Reports a business error in the context of a running task.

  The `error_code` must be specified to identify the BPMN error handler.
  See the official documentation for `Reporting Bpmn Error` in `User Tasks` on (https://docs.camunda.org/manual/latest/reference/bpmn20/tasks/user-task/#reporting-bpmn-error).

  ## Examples

      iex> Cain.UserTask.trigger_bpmn_error(%Cain.UserTask{}, "bpmn-error-543", "an_error_message", %{a_variable: "a_string_value", b_variable: true})
      :ok

  """
  @spec trigger_bpmn_error(user_task, String.t(), String.t(), Variable.t()) ::
          :ok | {:error, String.t()}
  def trigger_bpmn_error(%__MODULE__{id: task_id}, error_code, error_message, variables) do
    Task.handle_bpmn_error(task_id, %{
      "errorCode" => error_code,
      "errorMessage" => error_message,
      "variables" => variables
    })
  end
end
