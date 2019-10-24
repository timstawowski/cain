defmodule Cain.Rest.ExternalTask do
  defmodule Topic do
    @enforce_keys [:topic_name, :lock_duration]
    defstruct [
      :topic_name,
      :lock_duration,
      :variables,
      :local_variables,
      :business_key,
      :process_definition_id,
      :process_definition_id_in,
      :process_definition_key,
      :process_definition_key_in,
      :without_tenant_id,
      :tenant_id_in,
      :process_variables,
      :deserialize_values
    ]
  end

  defmodule GetList do
    @behaviour Cain.Rest.Endpoint

    @query_params [
      external_task_id: :string,
      topic_name: :string,
      worker_id: :string,
      locked: :boolean,
      not_locked: :boolean,
      with_retries_left: :boolean,
      no_retries_left: :boolean,
      lock_expiration_after: :string,
      lock_expiration_before: :string,
      activity_id: :string,
      activity_id_in: {:array, :string},
      execution_id: :string,
      process_instance_id: :string,
      process_definition_id: :string,
      tenant_id_in: {:array, :string},
      active: :boolean,
      priority_higher_than_or_equals: :integer,
      priority_lower_than_or_equals: :integer,
      suspended: :string,
      sort_by: :string,
      sort_order: :string,
      first_result: :integer,
      max_results: :integer
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/external-task",
        method: :get,
        query_params: @query_params,
        result_is_list?: false
      }
    end
  end

  defmodule FetchAndLock do
    @behaviour Cain.Rest.Endpoint

    @body_params [
      workerId: :string,
      maxTasks: :integer,
      usePriority: :boolean,
      asyncResponseTimeout: :integer,
      topics: {:array, :topic}
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/external-task/fetchAndLock",
        method: :get,
        body_params: @body_params,
        result_is_list?: false
      }
    end
  end

  defmodule Complete do
    @behaviour Cain.Rest.Endpoint

    @path_params [
      id: :string
    ]

    @body_params [
      workerId: :string,
      variables: :variables,
      localVariables: :variables
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/external-task",
        method: :get,
        path_params: @path_params,
        body_params: @body_params,
        result_is_list?: false
      }
    end
  end
end
