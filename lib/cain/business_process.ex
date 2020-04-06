defmodule Cain.BusinessProcess do
  # use GenServer
  use DynamicSupervisor

  defstruct [
    :key,
    :name,
    :suspended?,
    process_instances: [],
    process_instances_count: 0
  ]

  defmodule BusinessKeyError do
    @moduledoc false
    defexception [:message]
  end

  defmacro __using__(opts) do
    definition_key = Keyword.get(opts, :definition_key)

    cond do
      is_nil(definition_key) ->
        raise IO.warn("definition_key must be provided!")

      true ->
        Module.put_attribute(__CALLER__.module, :definition_key, definition_key)
        Module.register_attribute(__CALLER__.module, :business_keys, accumulate: true)
    end

    quote do
      def __definiton_key__ do
        @definition_key
      end

      def __validate_business_key__(business_key, func) do
        Cain.BusinessProcess.validate_business_key(@definition_key, business_key)
        |> case do
          :ok ->
            func.()

          _error ->
            {BusinessKeyError,
             "Business-key: ‘#{business_key}‘ not alive for process ‘#{@definition_key}‘"}
        end
      end

      ## BUSINESS PROCESS OPERATIONS ##

      # start strategies?
      def start do
        Cain.BusinessProcess.start(@definition_key)
      end

      def info do
        Cain.BusinessProcess.info(@definition_key)
      end

      def supsend(opts \\ []) do
        Cain.BusinessProcess.suspend_or_activate(@definition_key, :suspend, opts)
      end

      def activate(opts \\ []) do
        Cain.BusinessProcess.suspend_or_activate(@definition_key, :activate, opts)
      end

      ## PROCESS INSTANCE OPERATIONS ##

      def start_instance(
            business_key,
            params \\ %{},
            opts \\ []
          )

      def start_instance(business_key, params, opts) do
        __validate_business_key__(
          business_key,
          fn ->
            Cain.BusinessProcess.start_instance(@definition_key, business_key, params, opts)
          end
        )
      end

      def get_instances do
        Cain.BusinessProcess.get_instances(@definition_key)
      end

      def get_instance(business_key) do
        __validate_business_key__(
          business_key,
          fn -> Cain.BusinessProcess.get_instance(@definition_key, business_key) end
        )
      end

      def add_instance_variable(business_key, variables) do
        __validate_business_key__(
          business_key,
          fn ->
            Cain.BusinessProcess.add_instance_variable(@definition_key, business_key, variables)
          end
        )
      end

      ## ACTIVITY OPERATIONS ##

      # -- TASK --

      def get_user_tasks(business_key, task_names \\ [])

      def get_user_tasks(business_key, task_names) when is_binary(task_names) do
        get_user_tasks(business_key, [task_names])
      end

      def get_user_tasks(business_key, task_names) do
        __validate_business_key__(
          business_key,
          fn -> Cain.BusinessProcess.get_user_tasks(@definition_key, business_key, task_names) end
        )
      end

      def complete_user_task(business_key, task_name, variables \\ %{})
          when is_binary(business_key) and is_binary(task_name) do
        __validate_business_key__(
          business_key,
          fn ->
            Cain.BusinessProcess.complete_user_task(
              @definition_key,
              business_key,
              task_name,
              variables
            )
          end
        )
      end

      # def get_user_tasks(process_instance_id) do
      #   Task.get_list(%{"processInstanceId" => process_instance_id})
      # end

      # def get_activities(process_instance_id) do
      #   ProcessInstance.get_activity_instance(process_instance_id)
      # end

      # def get_variable_by_name(process_instance_id, variable_name, opts \\ []) do
      #   deserialize_values? = Keyword.get(opts, :deserialize_values?, true)

      #   ProcessInstance.Variables.get(
      #     %{
      #       id: process_instance_id,
      #       variable_name: variable_name
      #     },
      #     %{"deserializeValue" => deserialize_values?}
      #   )
      #   |> case do
      #     variable when is_map(variable) ->
      #       parse(%{variable_name => variable})

      #     error ->
      #       error
      #   end
      # end

      # def delete_process_instance(process_instance_id, opts \\ []) do
      #   with_history? = Keyword.get(opts, :with_history?, true)

      #   response = ProcessInstance.delete(process_instance_id, %{})

      #   if with_history? && response == :ok do
      #     ProcessInstance.delete(process_instance_id, %{}, history: true)
      #   else
      #     response
      #   end
      # end

      # def correlate_message(identifier, message, process_variables \\ %{}, opts \\ [])

      # def correlate_message(
      #       {:process_instance_id, process_instance_id},
      #       message,
      #       process_variables,
      #       opts
      #     ) do
      #   __correlate_message__(
      #     %{"processInstanceId" => process_instance_id},
      #     message,
      #     process_variables,
      #     opts
      #   )
      # end

      # def correlate_message({:business_key, business_key}, message, process_variables, opts) do
      #   __correlate_message__(%{"businessKey" => business_key}, message, process_variables, opts)
      # end

      # def __correlate_message__(identifier, message_name, process_variables, opts) do
      #   with_variables_in_return? = Keyword.get(opts, :with_variables_in_return?, false)
      #   result_enabled? = Keyword.get(opts, :result_enabled?, with_variables_in_return?)

      #   response =
      #     Map.merge(identifier, %{
      #       "messageName" => message_name,
      #       "processVariables" => cast(process_variables),
      #       "resultEnabled" => result_enabled?,
      #       "variablesInResultEnabled" => with_variables_in_return?
      #     })
      #     |> Message.correlate()

      #   if result_enabled? do
      #     Enum.map(response, fn chunk ->
      #       Cain.Response.Helper.variables_in_return(chunk, with_variables_in_return?)
      #     end)
      #   else
      #     response
      #   end
      # end
    end
  end

  def cast(info) do
    struct(__MODULE__, info)
  end

  def validate_business_key(definition_key, business_key) do
    Cain.ProcessInstance.Registry.business_keys(name(definition_key))
    |> Enum.member?(business_key)
    |> if do
      :ok
    else
      {:error, :business_key_not_found}
    end
  end

  # manually start up
  def start(definition_key) do
    case Cain.Endpoint.ProcessDefinition.get({:key, definition_key}) do
      {:error, %Cain.Endpoint.Error{message: msg}} ->
        {:error, msg}

      valid_response ->
        Cain.BusinessProcess.DynamicSupervisor.start_business_process(valid_response)
        :ok
    end
  end

  def info(definition_key) do
    Cain.Endpoint.ProcessDefinition.get({:key, definition_key})
    |> Cain.Response.Helper.pre_cast()
    |> Cain.BusinessProcess.cast()
    |> Map.put(:process_instances, get_process_instance_business_keys(name(definition_key)))
    |> Map.put(:process_instances_count, count_process_instances(name(definition_key)))
  end

  def suspend_or_activate(definition_key, :suspend, opts) do
    Cain.Endpoint.ProcessDefinition.get(%{key: definition_key})
    |> Map.get("suspended")
    |> if do
      {:error, :already_suspended}
    else
      suspend_or_activate(definition_key, %{"suspended" => true}, opts)
    end
  end

  def suspend_or_activate(definition_key, :activate, opts) do
    Cain.Endpoint.ProcessDefinition.get({:key, definition_key})
    |> Map.get("suspended")
    |> if do
      suspend_or_activate(definition_key, %{"suspended" => false}, opts)
    else
      {:error, :already_activated}
    end
  end

  def suspend_or_activate(definition_key, params, opts) do
    include_process_instances? = Keyword.get(opts, :include_process_instances?, true)
    execution_date = Keyword.get(opts, :execution_date, DateTime.utc_now())

    request =
      Map.merge(params, %{
        "includeProcessInstances" => include_process_instances?,
        "executionDate" => execution_date
      })

    Cain.Endpoint.ProcessDefinition.suspend({:key, definition_key}, request)
  end

  def get_instances(definition_key) do
    get_process_instance_business_keys(name(definition_key))
    |> Enum.map(&Cain.ProcessInstance.find(name(definition_key), &1))
  end

  def get_instance(definition_key, business_key) do
    Cain.ProcessInstance.find(name(definition_key), business_key)
  end

  def add_instance_variable(definition_key, business_key, variables) do
    Cain.ProcessInstance.add_variables(name(definition_key), business_key, variables)
  end

  def get_user_tasks(definition_key, business_key, user_task_names) do
    Cain.ProcessInstance.get_user_tasks(name(definition_key), business_key, user_task_names)
  end

  def complete_user_task(definition_key, business_key, task_name, variables) do
    Cain.ProcessInstance.complete_user_task(
      name(definition_key),
      business_key,
      task_name,
      variables
    )
  end

  ### DynamicSupervisor Impl ###

  def start_instance(definition_key, business_key, variables, opts) do
    with_variables_in_return? = Keyword.get(opts, :with_variables_in_return?, true)
    strategy = Keyword.get(opts, :strategy, {:key, definition_key})

    start_instructions =
      Keyword.get(opts, :start_instructions)
      |> __MODULE__.create_instructions()

    variables = Cain.Variable.cast(variables)

    request = %{
      "businessKey" => business_key,
      "variables" => variables,
      "startInstructions" => start_instructions,
      "withVariablesInReturn" => with_variables_in_return?
    }

    process_instance =
      Cain.Endpoint.ProcessDefinition.start_instance(strategy, request)
      |> Cain.Response.Helper.variables_in_return(with_variables_in_return?)

    spec = {Cain.ProcessInstance, [name(definition_key), process_instance]}

    case DynamicSupervisor.start_child(name(definition_key), spec) do
      {:ok, _pid} -> :ok
      error -> error
    end
  end

  def start_link(business_process_key) do
    DynamicSupervisor.start_link(__MODULE__, [],
      name: Module.concat(__MODULE__, business_process_key)
    )
  end

  @impl true
  def init(_init_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
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

  defp name(definition_key), do: Module.concat(__MODULE__, definition_key)

  defp count_process_instances(business_process) when is_atom(business_process) do
    Elixir.DynamicSupervisor.count_children(business_process)
    |> Map.get(:workers)
  end

  defp get_process_instance_business_keys(business_process) do
    Cain.ProcessInstance.Registry.business_keys(business_process)
  end
end
