defmodule Cain.BusinessProcess do
  use GenServer
  alias __MODULE__

  alias Cain.Endpoint.{
    ProcessDefinition
  }

  defstruct [
    :key,
    :name,
    :suspended?,
    :process_instances,
    :process_instances_count
  ]

  defmodule State do
    defstruct [
      :category,
      :deployment_id,
      :description,
      :diagram,
      :history_time_to_live,
      :id,
      :key,
      :name,
      :resource,
      :startable_in_tasklist,
      :suspended?,
      :tenant_id,
      :version,
      :version_tag,
      :process_instances
    ]
  end

  defmacro __using__(opts) do
    definition_key = Keyword.get(opts, :definition_key)

    cond do
      is_nil(definition_key) ->
        raise IO.warn("definition_key must be provided!")

      true ->
        Module.put_attribute(__CALLER__.module, :definition_key, definition_key)
    end

    quote do
      ## BUSINESS PROCESS OPERATIONS ##

      # start strategies?
      def start do
        Cain.BusinessProcess.start(@definition_key)
      end

      def info do
        Cain.BusinessProcess.get(@definition_key)
        |> Cain.BusinessProcess.cast()
      end

      def version do
        Cain.BusinessProcess.get_field_value(@definition_key, :version)
      end

      def supsend(opts \\ []) do
        Cain.BusinessProcess.suspend_or_activate(@definition_key, opts, true)
      end

      def activate(opts \\ []) do
        Cain.BusinessProcess.suspend_or_activate(@definition_key, opts, false)
      end

      def suspend_instance(business_key) do
      end

      ## PROCESS INSTANCE OPERATIONS ##

      def start_instance(
            business_key,
            params \\ %{},
            opts \\ []
          )

      def start_instance(business_key, params, opts) do
        Cain.BusinessProcess.start_instance(@definition_key, business_key, params, opts)
      end

      def all_instances do
        Cain.BusinessProcess.all_instances(@definition_key)
      end

      def find_instance(business_key) do
        Cain.BusinessProcess.all_instances(@definition_key, only: business_key)
      end

      def add_instance_process_variable(business_key, variables) do
        Cain.BusinessProcess.add_process_variable(@definition_key, business_key, variables)
      end

      ## ACTIVITY OPERATIONS ##

      # -- TASK --
      def get_user_tasks(business_key, task_names \\ []) do
        Cain.BusinessProcess.get_user_tasks(@definition_key, business_key, task_names)
      end

      def complete_user_task(business_key, task_name, variables) do
        Cain.BusinessProcess.complete_user_task(
          @definition_key,
          business_key,
          task_name,
          variables
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

  def cast(%State{process_instances: process_instances} = state) do
    business_keys = Enum.map(process_instances, &Map.get(&1, :business_key))

    params =
      state
      |> Map.from_struct()
      |> Map.put(:process_instances_count, Enum.count(process_instances))
      |> Map.put(:process_instances, business_keys)

    struct(__MODULE__, params)
  end

  def start(definition_key) do
    Cain.Endpoint.ProcessDefinition.get(%{key: definition_key})
    |> Cain.BusinessProcess.DynamicSupervisor.start_business_process()

    :ok
  end

  def start_instance(definition_key, business_key, params, opts) do
    with_variables_in_return? = Keyword.get(opts, :with_variables_in_return?, true)

    start_instructions =
      Keyword.get(opts, :start_instructions)
      |> BusinessProcess.create_instructions()

    strategy = Keyword.get(opts, :strategy, {:key, definition_key})
    variables = Cain.Variable.cast(params)

    request = %{
      "businessKey" => business_key,
      "variables" => variables,
      "startInstructions" => start_instructions,
      "withVariablesInReturn" => with_variables_in_return?
    }

    ProcessDefinition.start_instance(strategy, request)
    |> Cain.Response.Helper.variables_in_return(with_variables_in_return?)
    |> Cain.ProcessInstance.DynamicSupervisor.start_instance()
    |> case do
      {:ok, _pid} -> :ok
      error -> error
    end
  end

  def suspend_or_activate(definition_key, opts, mode) do
    GenServer.call(via(definition_key), {:suspend_or_activate, opts, mode})
  end

  def all_instances(definition_key, opts \\ [])

  def all_instances(definition_key, opts) do
    business_key = Keyword.get(opts, :only)
    all_instances = GenServer.call(via(definition_key), {:get_field_value, :process_instances})

    if not is_nil(business_key) do
      Enum.filter(all_instances, fn instance ->
        instance.business_key == business_key
      end)
      |> List.first()
    else
      all_instances
    end
  end

  def get_user_tasks(definition_key, business_key, user_task_names) do
    GenServer.call(via(definition_key), {:get_user_tasks, business_key, user_task_names})
  end

  def complete_user_task(definition_key, business_key, user_task_name, variables) do
    GenServer.call(
      via(definition_key),
      {:complete_user_task, business_key, user_task_name, variables}
    )
  end

  def add_process_variable(definition_key, business_key, variables) do
    GenServer.cast(via(definition_key), {:operate_process_instance, business_key, variables})
  end

  def start_link(%{"key" => definition_key} = business_process) do
    GenServer.start_link(__MODULE__, business_process, name: via(definition_key))
  end

  def get_field_value(business_process, field_value) do
    GenServer.call(via(business_process), {:get_field_value, field_value})
  end

  def get(business_process) do
    GenServer.call(via(business_process), :get)
  end

  def via(definition_key) do
    {:via, Cain.BusinessProcess.Registry, {:definition_key, definition_key}}
  end

  # SERVER

  def init(business_process) do
    state = struct(State, Cain.Response.Helper.pre_cast(business_process))
    {:ok, state, {:continue, :init_running_instances}}
  end

  def handle_continue(
        :init_running_instances,
        %State{key: process_definition_key} = business_process
      ) do
    init_process_instances_for(process_definition_key)

    {:noreply, business_process, {:continue, :add_process_instances}}
  end

  def handle_continue(
        :add_process_instances,
        %State{id: business_process_id} = business_process
      ) do
    process_instances = update_process_instances(business_process_id, :all)

    {:noreply, %{business_process | process_instances: process_instances}}
  end

  def handle_cast(
        {:operate_process_instance, business_key, variables},
        %{
          id: definition_id,
          process_instances: process_instances
        } = state
      ) do
    process_instance_id =
      process_instances
      |> process_instance_by_business_key(business_key)
      |> process_instance_id

    updated_instances =
      Cain.ProcessInstance.add_variables(definition_id, process_instance_id, variables)
      |> update_process_instances(business_key, process_instances)

    {:noreply, %{state | process_instances: updated_instances}}
  end

  def handle_call(
        {:complete_user_task, business_key, user_task_name, variables},
        _from,
        %{
          process_instances: process_instances
        } = business_process
      ) do
    reply =
      case process_instance_by_business_key(process_instances, business_key) do
        %Cain.ProcessInstance{__engine_state__: %{__snapshot__: snapshot}} ->
          get_user_task_activities(snapshot, [user_task_name])
          |> List.first()
          |> Cain.ActivityInstance.UserTask.complete(variables)

        # TODO update variables + snapshot

        nil ->
          []
      end

    {:reply, reply, business_process}
  end

  def handle_call(
        {:get_user_tasks, business_key, user_task_names},
        _from,
        %{
          process_instances: process_instances
        } = business_process
      ) do
    reply =
      case process_instance_by_business_key(process_instances, business_key) do
        %Cain.ProcessInstance{__engine_state__: %{__snapshot__: snapshot}, user_tasks: user_tasks} ->
          filter = if Enum.empty?(user_task_names), do: user_tasks, else: user_task_names

          get_user_task_activities(snapshot, filter)
          |> Enum.map(&Cain.UserTask.purify/1)

        nil ->
          []
      end

    {:reply, reply, business_process}
  end

  def handle_call({:suspend_or_activate, _opts, true}, _from, %{suspended?: true} = state) do
    {:reply, {:error, :already_suspend}, state}
  end

  def handle_call({:suspend_or_activate, _opts, false}, _from, %{suspended?: false} = state) do
    {:reply, {:error, :already_active}, state}
  end

  def handle_call(
        {:suspend_or_activate, opts, mode},
        _from,
        %{
          suspended?: suspended?,
          key: key
        } = state
      ) do
    include_process_instances? = Keyword.get(opts, :include_process_instances?, true)
    execution_date = Keyword.get(opts, :execution_date)

    request = %{
      "executionDate" => execution_date,
      "includeProcessInstances" => include_process_instances?,
      "suspended" => mode
    }

    response = Cain.Endpoint.ProcessDefinition.suspend({:key, key}, request)

    state =
      if response == :ok do
        %{state | suspended?: not suspended?}
      else
        state
      end

    {:reply, :ok, state}
  end

  def handle_call({:get_field_value, field_value}, _from, parent_activity_instance) do
    {:reply, Map.get(parent_activity_instance, field_value), parent_activity_instance}
  end

  def handle_call(:get, _from, parent_activity_instance) do
    {:reply, parent_activity_instance, parent_activity_instance}
  end

  def init_process_instances_for(process_definition_key) do
    # schedule work for state updates
    %{"processDefinitionKey" => process_definition_key}
    |> Cain.Endpoint.ProcessInstance.get_list()
    |> Enum.each(&Cain.ProcessInstance.DynamicSupervisor.start_instance/1)
  end

  defp update_process_instances(business_process_id, :all) do
    Cain.ProcessInstance.Registry.registered()
    |> Map.keys()
    |> Enum.filter(fn {:process_definition_id, process_definition_id, _} ->
      process_definition_id == business_process_id
    end)
    |> Enum.map(fn {:process_definition_id, process_definition_id,
                    {:process_instance_id, process_instance_id}} ->
      Cain.ProcessInstance.get_process_instance(
        process_definition_id,
        process_instance_id
      )
    end)
  end

  defp update_process_instances(new_instance, business_key, process_instances) do
    Enum.reduce(process_instances, [], fn process_instance, acc ->
      if process_instance.business_key == business_key do
        acc ++ [new_instance]
      else
        acc ++ [process_instance]
      end
    end)
  end

  defp get_user_task_activities(snapshot, user_task_names) do
    Cain.ActivityInstance.map_by_type(snapshot, "userTask")
    |> Enum.map(&Cain.ActivityInstance.cast/1)
    |> Enum.filter(fn %{"name" => name} -> Enum.member?(user_task_names, name) end)
  end

  defp process_instance_id(%Cain.ProcessInstance{
         __engine_state__: %{__process_instance_id__: process_instance_id}
       }),
       do: process_instance_id

  defp process_instance_by_business_key(process_instances, given_business_key) do
    Enum.find(process_instances, &(&1.business_key == given_business_key))
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
