defmodule Cain.BusinessProcess do
  # alias Cain.ProcessInstance
  alias __MODULE__
  alias Cain.Endpoint

  alias Cain.Endpoint.{
    ProcessDefinition,
    ProcessInstance,
    Task,
    Message
  }

  defmacro __using__(params) do
    key = Keyword.get(params, :definition_key)
    init_variables = Keyword.get(params, :init_variables)
    forms_spec = Keyword.get(params, :forms, [])

    cond do
      is_nil(key) ->
        raise IO.warn("definition_key must be provided!")

      true ->
        Module.put_attribute(__CALLER__.module, :key, key)
    end

    quote do
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
        variables = Cain.Variable.cast(params, unquote(init_variables))

        request = %{
          "businessKey" => business_key,
          "variables" => variables,
          "startInstructions" => start_instructions,
          "withVariablesInReturn" => true
        }

        ProcessDefinition.start_instance(strategy, request)
        |> Endpoint.submit()

        # |> case do
        #   {:ok, response} ->
        #     response
        #     |> BusinessProcess.format_response()

        #     # |>
        # end
      end

      def get_current_process_instance(super_process_instance_id) do
        ProcessInstance.get_list(%{
          "superProcessInstance" => super_process_instance_id
        })
        |> Endpoint.submit()
      end

      def get_process_instance_by_business_key(business_key) do
        ProcessInstance.get_list(%{
          "businessKey" => business_key,
          "processDefinitionKey" => @key
        })
        |> Endpoint.submit()
      end

      def get_current_activity(process_instance_id) do
        process_instance_id
        |> ProcessInstance.get_activity_instance()
        |> Endpoint.submit()
      end

      def get_variable_by_name(process_instance_id, variable_name, opts \\ []) do
        deserializedValues? = Keyword.get(opts, :deserialized_values?, true)

        ProcessInstance.Variable.get(
          %{
            id: process_instance_id,
            variable_name: variable_name
          },
          %{"deserializeValue" => deserializedValues?}
        )
        |> Endpoint.submit()
      end

      def delete_process_instance(process_instance_id, opts \\ []) do
        active? = Keyword.get(opts, :active?, true)
        with_history? = Keyword.get(opts, :with_history?, true)

        process_instance_id
        |> ProcessInstance.delete()
        |> Endpoint.submit()
        |> case do
          {:ok, _resposne} ->
            if with_history? do
              with {:ok, _resposne} <-
                     process_instance_id
                     |> ProcessInstance.delete()
                     |> Endpoint.submit_history() do
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

      # def get_current_user_task(business_key, opts \\ [], forms_spec \\ unquote(forms_spec))

      # def get_current_user_task(business_key, opts, forms_spec) do
      #   with_form_data? = Keyword.get(opts, :with_form_data?, false)

      #   {:ok, current_tasks} =
      #     Task.get_list(%{
      #       # "taskDefinitionKey" => task_definition_key,
      #       "processInstanceBusinessKey" => business_key,
      #       # "processDefinitionKey" => @key,
      #       "active" => true
      #     })
      #     |> Endpoint.submit()

      #   if with_form_data? do
      #     task_definition_key =
      #       List.first(current_tasks)
      #       |> Map.get("taskDefinitionKey")
      #       |> String.to_existing_atom()

      #     Enum.map(current_tasks, fn %{"id" => task_id} = task ->
      #       Task.get_task_form_variables(task_id, %{
      #         "variableNames" =>
      #           Keyword.get(forms_spec, task_definition_key)
      #           |> Keyword.keys()
      #           |> Enum.map(&Atom.to_string/1)
      #           |> Enum.join(",")
      #       })
      #       |> Endpoint.submit()
      #     end)
      #   else
      #     current_tasks
      #   end
      # end

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
        |> Endpoint.submit()
      end

      def trigger_user_task_bpmn_error(business_key, error_code, error_message, variables) do
        Task.get_list(%{
          "processInstanceBusinessKey" => business_key,
          # "processDefinitionKey" => @key,
          "active" => true
        })
        |> Endpoint.submit()
        |> case do
          {:ok, []} ->
            {:error, "No open tasks for claim: #{business_key}!"}

          {:ok, [%{"id" => task_id}] = response} ->
            Task.handle_bpmn_error(task_id, %{
              "errorCode" => error_code,
              "errorMessage" => error_message,
              "variables" => variables
            })
            |> Endpoint.submit()
        end
      end

      def complete_user_task(
            business_key,
            params \\ %{},
            opts \\ [],
            forms_spec \\ unquote(forms_spec)
          )

      def complete_user_task(business_key, params, opts, forms_spec) do
        with_variables_in_return? = Keyword.get(opts, :with_variables_in_return?, false)
        task_definition_key = Keyword.get(opts, :task_definition_key)
        form_variables = Keyword.get(forms_spec, task_definition_key, false)

        Task.get_list(%{
          "processInstanceBusinessKey" => business_key,
          # "processDefinitionKey" => @key,
          "active" => true
        })
        |> Endpoint.submit()
        |> case do
          {:ok, []} ->
            {:error, "No open tasks for claim: #{business_key}!"}

          {:ok, [%{"id" => task_id}] = response} ->
            variables =
              if form_variables do
                Cain.Variable.cast(params, form_variables)
              else
                params
              end

            task_id
            |> Task.complete(%{
              "variables" => variables,
              "withVariablesInReturn" => with_variables_in_return?
            })
            |> Endpoint.submit()
            |> case do
              {:ok, variables} ->
                variables

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
