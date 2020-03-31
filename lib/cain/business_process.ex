defmodule Cain.BusinessProcess do
  use GenServer
  alias __MODULE__

  alias Cain.Endpoint.{
    ProcessDefinition,
    ProcessInstance,
    Task,
    Message
  }

  import Cain.Variable, only: [cast: 1, parse: 1]

  defstruct [
    :description,
    :history_time_to_live,
    :key,
    :name,
    :resource,
    :startable_in_tasklist,
    :suspended?,
    :version,
    :version_tag,
    :running_process_instances,
    :running_process_instances_count
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
      :version_tag
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
        |> Cain.ProcessInstance.DynamicSupervisor.start_instance()
        |> case do
          {:ok, _pid} -> {:ok, business_key}
          error -> error
        end
      end

      def get_running_instances do
        Cain.BusinessProcess.get_running_instances(@definition_key)
        # Cain.ProcessInstance.get_process_instance(nil, @definition_key)
        # ProcessInstance.get_list(%{"processDefinitionKey" => @definition_key})
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

        ProcessInstance.Variables.get(
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

  def cast(%State{} = state) do
    running_process_instances = get_running_instances(state.key)

    params =
      state
      |> Map.from_struct()
      |> Map.put(:running_process_instances, running_process_instances)
      |> Map.put(:running_process_instances_count, Enum.count(running_process_instances))

    struct(__MODULE__, params)
  end

  def start(definition_key) do
    Cain.Endpoint.ProcessDefinition.get(%{key: definition_key})
    |> Cain.BusinessProcess.DynamicSupervisor.start_business_process()
  end

  def get_running_instances(definition_key) do
    business_process = get(definition_key)

    business_process
    |> Map.get(:running_process_instances)
    |> case do
      nil ->
        Cain.ProcessInstance.Registry.registered()
        |> Map.keys()
        |> Enum.reduce([], fn {:process_definition_id, process_definition_id,
                               {:business_key, business_key}},
                              acc ->
          process_instance =
            Cain.ProcessInstance.get_process_instance(process_definition_id, business_key)
            |> Cain.ProcessInstance.cast()

          if process_definition_id == business_process.id do
            acc ++ [process_instance]
          else
            acc
          end
        end)

      running_process_instances ->
        running_process_instances
    end
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
    {:ok, struct(State, Cain.Response.Helper.pre_cast(business_process)),
     {:continue, :init_running_instances}}
  end

  def handle_continue(
        :init_running_instances,
        %State{key: process_definition_key} = business_process
      ) do
    init_process_instances_for(process_definition_key)

    {:noreply, business_process}
  end

  def handle_call({:get_field_value, field_value}, _from, parent_activity_instance) do
    {:reply, Map.get(parent_activity_instance, field_value), parent_activity_instance}
  end

  def handle_call(:get, _from, parent_activity_instance) do
    {:reply, parent_activity_instance, parent_activity_instance}
  end

  def init_process_instances_for(process_definition_key) do
    %{"processDefinitionKey" => process_definition_key}
    |> Cain.Endpoint.ProcessInstance.get_list()
    |> Enum.each(&Cain.ProcessInstance.DynamicSupervisor.start_instance/1)
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
