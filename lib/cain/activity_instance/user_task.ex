defmodule Cain.ActivityInstance.UserTask do
  alias Cain.{Endpoint.Task, Variable}

  @doc """
  Changes the assignee of a task to a specific user.
  """
  # TODO: Add validation on candidates
  @spec claim(map(), String.t()) ::
          :ok | {:already_claimed_by, String.t()} | {:error, String.t()}
  def claim(%{"assignee" => assignee}, _user_id) when not is_nil(assignee) do
    {:already_claimed_by, assignee}
  end

  def claim(%{"id" => id, "assignee" => nil}, user_id) do
    Task.claim(id, user_id)
  end

  @doc """
  Resets a task’s assignee if a assginee is set, otherwise returns `:not_claimed`
  """
  @spec unclaim(map()) :: :ok | :not_claimed | {:error, String.t()}
  def unclaim(%{"assignee" => nil}) do
    :not_claimed
  end

  def unclaim(%{"id" => id}) do
    Task.unclaim(id)
  end

  @doc """
  Changes the assignee of a task to a specific user.

  The difference with the Claim Task method is that this method does not check if the task already has a user assigned to it.
  """
  @spec set_assignee(map(), String.t()) :: :ok | {:error, String.t()}
  def set_assignee(%{"id" => id}, user_id) do
    Task.set_assignee(id, user_id)
  end

  @spec delegate(map(), String.t()) :: :ok | {:error, String.t()}
  def delegate(%{"id" => id}, user_id) do
    Task.delegate(id, user_id)
  end

  @spec resolve(map(), Variable.t()) :: :ok | {:error, String.t()}
  def resolve(%{"id" => id}, variables) do
    Task.resolve(id, variables)
  end

  @spec submit_form(map(), Variable.t(), list()) :: :ok | {:error, String.t()}
  def submit_form(%{"id" => task_id}, params, opts) do
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
  @spec complete(map(), Variable.t(), list()) ::
          :ok | Variable.t() | {:error, String.t()}
  def complete(%{"id" => task_id}, params \\ %{}, opts \\ []) do
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

      iex> Cain.maprigger_bpmn_error(%Cain.map, "bpmn-error-543", "an_error_message", %{a_variable: "a_string_value", b_variable: true})
      :ok

  """
  @spec trigger_bpmn_error(map(), String.t(), String.t(), Variable.t()) ::
          :ok | {:error, String.t()}
  def trigger_bpmn_error(%{"id" => task_id}, error_code, error_message, variables) do
    Task.handle_bpmn_error(task_id, %{
      "errorCode" => error_code,
      "errorMessage" => error_message,
      "variables" => variables
    })
  end
end
