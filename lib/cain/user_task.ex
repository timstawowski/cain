defmodule Cain.UserTask do
  @moduledoc false
  use Cain.Activity,
    extentional_fields: [
      {:identity_links, &Cain.Endpoint.Task.IdentityLinks.get_list/1},
      {:form_variables, &Cain.Endpoint.Task.get_task_form_variables/1}
    ]

  alias Cain.{Endpoint.Task, Variable}

  @type user_task() :: %Cain.UserTask{}

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
  Completes a task and updates process variables.

  To indicate whether the response should contain the process variables or not `with_variables_in_return?` can be set to `true` default is false.
  """
  @spec complete(Cain.UserTask.t(), Variable.t(), list()) ::
          :ok | Variable.t() | {:error, String.t()}
  def complete(%__MODULE__{id: task_id}, params \\ %{}, opts \\ []) do
    with_variables_in_return? = Keyword.get(opts, :with_variables_in_return?, true)
    variables = Variable.cast(params)

    Task.complete(task_id, %{
      "variables" => variables,
      "withVariablesInReturn" => with_variables_in_return?
    })
    |> case do
      response when is_map(response) ->
        Variable.parse(response)

      response ->
        response
    end
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
