defmodule Cain.BusinessProcess do
  # alias Cain.ProcessInstance
  alias __MODULE__

  alias Cain.Endpoint.{
    ProcessDefinition,
    ProcessInstance,
    Task,
    Message
  }

  defmacro __using__(opts) do
    key = Keyword.get(opts, :definition_key)
    client = Keyword.get(opts, :client, Cain.Client.Default)

    cond do
      is_nil(key) ->
        raise IO.warn("definition_key must be provided!")

      true ->
        Module.put_attribute(__CALLER__.module, :key, key)
    end

    quote do
      @deprecated "Will be removed in the upcoming version"
      def start_instance(
            business_key,
            params \\ %{},
            opts \\ []
          )

      def start_instance(business_key, params, opts) do
        start_instructions =
          Keyword.get(opts, :start_instructions)
          |> BusinessProcess.create_instructions()

        strategy = Keyword.get(opts, :strategy, {:key, @key})
        variables = Cain.Variable.cast(params)

        request = %{
          "businessKey" => business_key,
          "variables" => variables,
          "startInstructions" => start_instructions,
          "withVariablesInReturn" => true
        }

        ProcessDefinition.start_instance(strategy, request)
        |> unquote(client).submit()
      end

      @deprecated "Will be removed in the upcoming version"
      def get_current_process_instance(super_process_instance_id) do
        ProcessInstance.get_list(%{
          "superProcessInstance" => super_process_instance_id
        })
        |> unquote(client).submit()
      end

      @deprecated "Will be removed in the upcoming version"
      def get_process_instance_by_business_key(business_key) do
        ProcessInstance.get_list(%{
          "businessKey" => business_key,
          "processDefinitionKey" => @key
        })
        |> unquote(client).submit()
      end

      @deprecated "Will be removed in the upcoming version"
      def get_current_activity(process_instance_id) do
        process_instance_id
        |> ProcessInstance.get_activity_instance()
        |> unquote(client).submit()
      end

      @deprecated "Will be removed in the upcoming version"
      def get_variable_by_name(process_instance_id, variable_name, opts \\ []) do
        deserializedValues? = Keyword.get(opts, :deserialized_values?, true)

        ProcessInstance.Variable.get(
          %{
            id: process_instance_id,
            variable_name: variable_name
          },
          %{"deserializeValue" => deserializedValues?}
        )
        |> unquote(client).submit()
      end

      @deprecated "Will be removed in the upcoming version"
      def delete_process_instance(process_instance_id, opts \\ []) do
        active? = Keyword.get(opts, :active?, true)
        with_history? = Keyword.get(opts, :with_history?, true)

        process_instance_id
        |> ProcessInstance.delete()
        |> unquote(client).submit()
        |> case do
          {:ok, _resposne} ->
            if with_history? do
              with {:ok, _resposne} <-
                     process_instance_id
                     |> ProcessInstance.delete()
                     |> unquote(client).submit_history() do
                :ok
              else
                history_error ->
                  history_error
              end
            else
              :ok
            end

          error ->
            error
        end
      end

      @deprecated "Will be removed in the upcoming version"
      def correlate_message(identifier, message, process_variables \\ %{}, opts \\ [])

      def correlate_message(
            {:process_instance_id, process_instance_id},
            message,
            process_variables,
            opts
          ) do
        __correlate_message__(
          %{"processInstanceId" => process_instance_id},
          message,
          process_variables,
          opts
        )
      end

      def correlate_message({:business_key, business_key}, message, process_variables, opts) do
        __correlate_message__(%{"businessKey" => business_key}, message, process_variables, opts)
      end

      def __correlate_message__(identifier, message_name, process_variables, opts) do
        with_result_variables_in_return? = Keyword.get(opts, :with_variables_in_return?, false)

        Map.merge(identifier, %{
          "messageName" => message_name,
          "processVariables" => process_variables,
          "resultEnabled" => with_result_variables_in_return?,
          "variablesInResultEnabled" => with_result_variables_in_return?
        })
        |> Message.correlate()
        |> unquote(client).submit()
      end

      @deprecated "Will be removed in the upcoming version"
      def trigger_user_task_bpmn_error(business_key, error_code, error_message, variables) do
        Task.get_list(%{
          "processInstanceBusinessKey" => business_key,
          # "processDefinitionKey" => @key,
          "active" => true
        })
        |> unquote(client).submit()
        |> case do
          {:ok, []} ->
            {:error, "No open tasks for claim: #{business_key}!"}

          {:ok, [%{"id" => task_id}] = response} ->
            Task.handle_bpmn_error(task_id, %{
              "errorCode" => error_code,
              "errorMessage" => error_message,
              "variables" => variables
            })
            |> unquote(client).submit()
        end
      end

      @deprecated "Will be removed in the upcoming version"
      def complete_user_task(
            business_key,
            params \\ %{},
            opts \\ []
          )

      def complete_user_task(business_key, params, opts) do
        with_variables_in_return? = Keyword.get(opts, :with_variables_in_return?, true)
        variables = Cain.Variable.cast(params)

        Task.get_list(%{
          "processInstanceBusinessKey" => business_key,
          # "processDefinitionKey" => @key,
          "active" => true
        })
        |> unquote(client).submit()
        |> case do
          {:ok, []} ->
            {:error, "No open tasks for claim: #{business_key}!"}

          {:ok, [%{"id" => task_id}] = response} ->
            task_id
            |> Task.complete(%{
              "variables" => variables,
              "withVariablesInReturn" => with_variables_in_return?
            })
            |> unquote(client).submit()
            |> case do
              {:ok, variables} ->
                variables
                |> Cain.Variable.parse()

              error ->
                error
            end

          {:ok, list_of_matching_tasks} ->
            {:error, "Multiple open tasks found for claim: #{business_key}"}

          error ->
            error
        end
      end
    end
  end

  def create_instructions(nil) do
    nil
  end

  def create_instructions({:start_transition, transition_id}) do
    %{"type" => "startTransition", "transitionId" => transition_id}
  end

  def create_instructions({start_at_activity, activity_id})
      when start_at_activity in [:start_before_activity, :start_after_activity] do
    %{"type" => activity_type(start_at_activity), "activityId" => activity_id}
  end

  def create_instructions(start_instructions) do
    start_instructions
    |> Enum.map(&create_instructions(&1))
  end

  defp activity_type(:start_before_activity), do: "startBeforeActivity"
  defp activity_type(:start_after_activity), do: "startAfterActivity"
end
