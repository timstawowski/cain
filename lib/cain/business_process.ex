defmodule Cain.BusinessProcess do
  # alias Cain.ProcessInstance
  alias __MODULE__

  alias Cain.Endpoint.{
    ProcessDefinition,
    ProcessInstance,
    Task,
    Message
  }

  import Cain.Variable, only: [cast: 1, parse: 1]

  defmacro __using__(params) do
    definition_key = Keyword.get(params, :definition_key)

    cond do
      is_nil(definition_key) ->
        raise IO.warn("definition_key must be provided!")

      true ->
        Module.put_attribute(__CALLER__.module, :definition_key, definition_key)
    end

    quote do
      def start_instance(
            business_key,
            params \\ %{},
            opts \\ []
          )

      def start_instance(business_key, params, opts) do
        with_variables_in_return? = Keyword.get(opts, :with_variables_in_return?, true)

        start_instructions =
          Keyword.get(opts, :start_instructions)
          |> BusinessProcess.create_instructions()

        strategy = Keyword.get(opts, :strategy, {:key, @definition_key})
        variables = cast(params)

        request = %{
          "businessKey" => business_key,
          "variables" => variables,
          "startInstructions" => start_instructions,
          "withVariablesInReturn" => with_variables_in_return?
        }

        ProcessDefinition.start_instance(strategy, request)
        |> Cain.Response.Helper.variables_in_return(with_variables_in_return?)
      end

      def get_running_instances do
        ProcessInstance.get_list(%{"processDefinitionKey" => @definition_key})
      end

      def get_process_instance_by_business_key(business_key) do
        ProcessInstance.get_list(%{
          "businessKey" => business_key,
          "processDefinitionKey" => @definition_key
        })
      end

      def get_user_tasks(process_instance_id) do
        Task.get_list(%{"processInstanceId" => process_instance_id})
      end

      def get_activities(process_instance_id) do
        ProcessInstance.get_activity_instance(process_instance_id)
      end

      def get_variable_by_name(process_instance_id, variable_name, opts \\ []) do
        deserialize_values? = Keyword.get(opts, :deserialize_values?, true)

        ProcessInstance.Variable.get(
          %{
            id: process_instance_id,
            variable_name: variable_name
          },
          %{"deserializeValue" => deserialize_values?}
        )
        |> case do
          variable when is_map(variable) ->
            parse(%{variable_name => variable})

          error ->
            error
        end
      end

      def delete_process_instance(process_instance_id, opts \\ []) do
        with_history? = Keyword.get(opts, :with_history?, true)

        response = ProcessInstance.delete(process_instance_id, %{})

        if with_history? && response == :ok do
          ProcessInstance.delete(process_instance_id, %{}, history: true)
        else
          response
        end
      end

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
        with_variables_in_return? = Keyword.get(opts, :with_variables_in_return?, false)
        result_enabled? = Keyword.get(opts, :result_enabled?, with_variables_in_return?)

        response =
          Map.merge(identifier, %{
            "messageName" => message_name,
            "processVariables" => cast(process_variables),
            "resultEnabled" => result_enabled?,
            "variablesInResultEnabled" => with_variables_in_return?
          })
          |> Message.correlate()

        if result_enabled? do
          Enum.map(response, fn chunk ->
            Cain.Response.Helper.variables_in_return(chunk, with_variables_in_return?)
          end)
        else
          response
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
