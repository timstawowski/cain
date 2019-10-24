defmodule Cain.Rest.UserOperationLog do
  defmodule GetUserOperationLog do
    @behaviour Cain.Rest.Endpoint

    @query_params [
      deployment_id: :string,
      process_definition_id: :string,
      process_definition_key: :string,
      process_instance_id: :string,
      execution_id: :string,
      case_definition_id: :string,
      case_instance_id: :string,
      case_execution_id: :string,
      task_id: :string,
      job_id: :string,
      job_definition_id: :string,
      user_id: :string,
      operation_id: :string,
      operation_type: :string,
      entity_type: :string,
      property: :string,
      # format: yyyy-MM-dd'T'HH:mm:ss, e.g., 2014-02-25T14:58:37.
      after_timestamp: :string,
      # format:  yyyy-MM-dd'T'HH:mm:ss, e.g., 2014-02-25T14:58:37.
      before_timestamp: :string,
      sort_by: :string,
      sort_order: :string,
      first_result: :string,
      max_results: :string
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/history/user-operation",
        method: :get,
        query_params: @query_params,
        result_is_list?: true
      }
    end
  end
end
