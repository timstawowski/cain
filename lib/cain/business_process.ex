defmodule Cain.BusinessProcess do
  use DynamicSupervisor

  alias Cain.{
    BusinessKey,
    Variable
  }

  defstruct [
    :key,
    :name,
    :suspended?,
    process_instances: [],
    process_instances_count: 0
  ]

  defmacro __using__(opts) do
    definition_key = Keyword.get(opts, :definition_key)

    cond do
      is_nil(definition_key) ->
        raise IO.warn("definition_key must be provided!")

      true ->
        Module.put_attribute(__CALLER__.module, :definition_key, definition_key)
    end

    quote do
      import BusinessKey, only: [is_business_key: 1]
      # import Cain.Variable

      def __definiton_key__ do
        @definition_key
      end

      def __validate_business_key__(business_key, func) do
        if Cain.BusinessProcess.registered_business_key?(@definition_key, business_key) do
          func.()
        else
          {:error, :unknown_business_key}
        end
      end

      ## BUSINESS PROCESS OPERATIONS ##

      # start strategies?
      @spec start() :: :ok
      def start do
        Cain.BusinessProcess.start(@definition_key)
      end

      @spec info() :: %Cain.BusinessProcess{}
      def info do
        Cain.BusinessProcess.info(@definition_key)
      end

      def suspend(opts \\ [])

      @spec suspend(list()) :: :ok | {:error, :already_supsend}
      def suspend(opts) when is_list(opts) do
        Cain.BusinessProcess.suspend_or_activate(@definition_key, :suspend, opts)
      end

      def activate(opts \\ [])

      @spec activate(list()) :: :ok | {:error, :already_activate}
      def activate(opts) when is_list(opts) do
        Cain.BusinessProcess.suspend_or_activate(@definition_key, :activate, opts)
      end

      ## PROCESS INSTANCE OPERATIONS ##

      def start_instance(
            business_key,
            params \\ %{},
            opts \\ []
          )

      @spec start_instance(BusinessKey.t(), Variable.t(), list()) ::
              :ok | {:error, :duplicate_business_key}
      def start_instance(business_key, params, opts)
          when is_business_key(business_key) and is_map(params) and is_list(opts) do
        Cain.BusinessProcess.start_instance(@definition_key, business_key, params, opts)
      end

      @spec activate_instance(BusinessKey.t()) :: :ok | {:error, :already_active}
      def activate_instance(business_key) when is_business_key(business_key) do
        Cain.BusinessProcess.suspend_or_activate_instance(
          @definition_key,
          business_key,
          :activate
        )
      end

      @spec suspend_instance(BusinessKey.t()) :: :ok | {:error, :already_suspend}
      def suspend_instance(business_key) when is_business_key(business_key) do
        Cain.BusinessProcess.suspend_or_activate_instance(@definition_key, business_key, :suspend)
      end

      @spec get_instances() :: list(%Cain.ProcessInstance{}) | list()
      def get_instances do
        Cain.BusinessProcess.get_instances(@definition_key)
      end

      @spec get_instance(BusinessKey.t()) ::
              %Cain.ProcessInstance{} | nil | {:error, :unknown_business_key}
      def get_instance(business_key) when is_business_key(business_key) do
        __validate_business_key__(
          business_key,
          fn -> Cain.BusinessProcess.get_instance(@definition_key, business_key) end
        )
      end

      def get_instance(business_key),
        do: raise(Cain.BusinessKeyError, "Invalid type for business key")

      @spec add_instance_variable(Businesskey.t(), Variable.t()) ::
              :ok | {:error, :unknown_business_key}
      def add_instance_variable(business_key, variables)
          when is_business_key(business_key) and is_map(variables) do
        __validate_business_key__(
          business_key,
          fn ->
            Cain.BusinessProcess.add_instance_variable(@definition_key, business_key, variables)
          end
        )
      end

      def delete_instance(business_key, opts \\ [])

      @spec delete_instance(BusinessKey.t(), list()) :: :ok | {:error, :unknown_business_key}
      def delete_instance(business_key, opts)
          when is_business_key(business_key) and is_list(opts) do
        Cain.BusinessProcess.delete_instance(@definition_key, business_key, opts)
      end

      ## ACTIVITY OPERATIONS ##

      # -- TASK --

      @spec get_instance_user_task(BusinessKey.t(), list(String.t()) | String.t()) ::
              list(%Cain.UserTask{})
              | list()
              | {:error, :multiple_task_with_same_name}
              | {:error, :unknown_business_key}
      def get_instance_user_task(business_key, task_names)
          when is_business_key(business_key) and is_binary(task_names) do
        get_instance_user_tasks(business_key, [task_names])
        |> case do
          [user_task] -> user_task
          [_ | _] -> {:error, :multiple_task_with_same_name}
          [] -> []
        end
      end

      def get_instance_user_tasks(business_key, task_names)
          when is_business_key(business_key) and is_list(task_names) do
        __validate_business_key__(
          business_key,
          fn ->
            Cain.BusinessProcess.get_instance_user_tasks(
              @definition_key,
              business_key,
              task_names
            )
          end
        )
      end

      @spec complete_user_task(BusinessKey.t(), String.t(), Variable.t()) ::
              :ok | {:error, :unknown_business_key}
      def complete_user_task(business_key, task_name, variables \\ %{})
          when is_business_key(business_key) and is_binary(task_name) and is_map(variables) do
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

      @spec claim_user_task(BusinessKey.t(), String.t(), String.t()) ::
              :ok | {:already_claimed_by, String.t()}
      def claim_user_task(business_key, task_name, assginee) when is_business_key(business_key) do
        Cain.BusinessProcess.claim_user_task(@definition_key, business_key, task_name, assginee)
      end

      @spec unclaim_user_task(BusinessKey.t(), String.t()) ::
              :ok | {:already_claimed_by, String.t()}
      def unclaim_user_task(business_key, task_name)
          when is_business_key(business_key) do
        Cain.BusinessProcess.unclaim_user_task(@definition_key, business_key, task_name)
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
    Cain.Endpoint.ProcessDefinition.get({:key, definition_key})
    |> Map.get("suspended")
    |> if do
      {:error, :already_suspend}
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
      {:error, :already_active}
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

  def suspend_or_activate_instance(definition_key, business_key, :suspend) do
    Cain.ProcessInstance.suspend(name(definition_key), business_key)
  end

  def suspend_or_activate_instance(definition_key, business_key, :activate) do
    Cain.ProcessInstance.activate(name(definition_key), business_key)
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

  def delete_instance(definition_key, business_key, opts) do
    Cain.ProcessInstance.delete(name(definition_key), business_key, opts)
    |> case do
      :ok ->
        pid =
          Cain.ProcessInstance.Registry.registered()
          |> Map.get({name(definition_key), business_key})

        DynamicSupervisor.terminate_child(name(definition_key), pid)

      error ->
        error
    end
  end

  def get_instance_user_tasks(definition_key, business_key, user_task_names) do
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

  def claim_user_task(defintion_key, business_key, user_task_name, assignee) do
    Cain.ProcessInstance.claim_user_task(
      name(defintion_key),
      business_key,
      user_task_name,
      assignee
    )
  end

  def unclaim_user_task(defintion_key, business_key, user_task_name) do
    Cain.ProcessInstance.unclaim_user_task(
      name(defintion_key),
      business_key,
      user_task_name
    )
  end

  ### DynamicSupervisor Impl ###
  def start_instance(definition_key, business_key, variables, opts) do
    if not registered_business_key?(definition_key, business_key) do
      start_instance(definition_key, business_key, variables, opts, true)
    else
      {:error, :duplicate_business_key}
    end
  end

  defp start_instance(definition_key, business_key, variables, opts, true) do
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

    case DynamicSupervisor.start_child(
           name(definition_key),
           {Cain.ProcessInstance, [name(definition_key), process_instance]}
         ) do
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

  def registered_business_key?(definition_key, business_key) do
    Cain.ProcessInstance.Registry.business_keys(name(definition_key))
    |> Enum.member?(business_key)
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
    business_process
    |> Elixir.DynamicSupervisor.count_children()
    |> Map.get(:workers)
  end

  defp get_process_instance_business_keys(business_process) do
    Cain.ProcessInstance.Registry.business_keys(business_process)
  end
end
