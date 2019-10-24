defmodule Cain.Rest.Task do
  defmodule GetList do
    @behaviour Cain.Rest.Endpoint

    @query_params [
      process_instance_id: :string,
      process_instance_business_key: :string,
      process_instance_business_key_expression: :string,
      process_instance_business_key_in: {:array, :string},
      process_instance_business_key_like: :string,
      process_instance_business_key_like_expression: :string,
      process_definition_id: :string,
      process_definition_key: :string,
      process_definition_key_in: :string,
      process_definition_name: :string,
      process_definition_name_like: :string,
      execution_id: :string,
      case_instance_id: :string,
      case_instance_business_key: :string,
      case_instance_business_key_like: :string,
      case_definition_id: :string,
      case_definition_key: :string,
      case_definition_name: :string,
      case_definition_name_like: :string,
      case_execution_id: :string,
      activity_instance_id_in: :string,
      tenant_id_in: :string,
      without_tenant_id: :string,
      assignee: :string,
      assignee_expression: :string,
      assignee_like: :string,
      assignee_like_expression: :string,
      assignee_in: :string,
      owner: :string,
      owner_expression: :string,
      candidate_group: :string,
      candidate_group_expression: :string,
      candidate_user: :string,
      candidate_user_expression: :string,
      include_assigned_task: :string,
      involved_user: :string,
      involved_user_expression: :string,
      assigned: :string,
      unassigned: :string,
      task_definition_key: :string,
      task_definition_key_in: :string,
      task_definition_key_like: :string,
      name: :string,
      name_not_equal: :string,
      name_like: :string,
      name_not_like: :string,
      description: :string,
      description_like: :string,
      priority: :string,
      max_priority: :string,
      min_priority: :string,
      due_date: :string,
      due_date_expression: :string,
      due_after: :string,
      due_after_expression: :string,
      due_before: :string,
      due_before_expression: :string,
      follow_up_date: :string,
      follow_up_date_expression: :string,
      follow_up_after: :string,
      follow_up_after_expression: :string,
      follow_up_before: :string,
      follow_up_before_expression: :string,
      follow_up_before_or_not_existent: :string,
      follow_up_before_or_not_existent_expression: :string,
      created_on: :string,
      created_on_expression: :string,
      created_after: :string,
      created_after_expression: :string,
      created_before: :string,
      created_before_expression: :string,
      delegation_state: :string,
      candidate_groups: {:array, :strig},
      candidate_groups_expression: :string,
      with_candidate_groups: :string,
      with_candidate_users: :string,
      without_candidate_groups: :string,
      without_candidate_users: :string,
      active: :boolean,
      suspended: :string,
      task_variables: :string,
      process_variables: :string,
      case_instance_variables: :string,
      variable_names_ignore_case: :string,
      variable_values_ignore_case: :string,
      parent_task_id: :string,
      sort_by: :string,
      sort_order: :string,
      first_result: :string,
      max_results: :string
    ]

    # @result_fields [
    #   id: :string,
    #   name: :string,
    #   assignee: :string,
    #   owner: :string,
    #   created: :string,
    #   due: :string,
    #   follow_up: :string,
    #   delegation_state: :string,
    #   description: :string,
    #   execution_id: :string,
    #   parent_task_id: :string,
    #   priority: :integer,
    #   process_definition_id: :string,
    #   process_instance_id: :string,
    #   case_execution_id: :string,
    #   case_definition_id: :string,
    #   case_instance_id: :string,
    #   task_definition_key: :string,
    #   suspended: :boolean,
    #   form_key: :string,
    #   tenant_id: :string
    # ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/task",
        method: :get,
        query_params: @query_params,
        result_is_list?: true
      }
    end
  end

  defmodule Complete do
    @behaviour Cain.Rest.Endpoint

    @path_params id: :string

    @body_parmas [
      variables: :variables
    ]

    def method() do
      :post
    end

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/task/{id}/complete",
        method: :post,
        path_params: @path_params,
        body_params: @body_parmas,
        result_is_list?: false
      }
    end
  end

  defmodule Update do
    @behaviour Cain.Rest.Endpoint

    @path_params id: :string

    @body_parmas [
      name: :string,
      description: :string,
      assignee: :string,
      owner: :string,
      delegation_state: :string,
      due: :string,
      follow_up: :string,
      priority: :integer,
      parent_task_id: :string,
      case_instance_id: :string,
      tenant_id: :string
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/task/{id}/",
        method: :put,
        path_params: @path_params,
        body_params: @body_parmas,
        result_is_list?: false
      }
    end
  end

  defmodule Claim do
    @behaviour Cain.Rest.Endpoint

    @path_params id: :string

    @body_parmas [
      user_id: :string
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/task/{id}/claim",
        method: :post,
        path_params: @path_params,
        body_params: @body_parmas,
        result_is_list?: false
      }
    end
  end

  defmodule Unclaim do
    @behaviour Cain.Rest.Endpoint

    @path_params id: :string

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/task/{id}/unclaim",
        method: :post,
        path_params: @path_params,
       result_is_list?: false
      }
    end
  end

  defmodule IdentityLinks do
    @behaviour Cain.Rest.Endpoint

    @path_params id: :string

    @query_params [
      type: :string
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/task/{id}/identity-links",
        method: :get,
        path_params: @path_params,
        query_params: @query_params,
        result_is_list?: true
      }
    end
  end

  defmodule SetAsignee do
    @behaviour Cain.Rest.Endpoint

    @path_params id: :string

    @body_params [
      user_id: :string
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/task/{id}/assignee",
        method: :post,
        path_params: @path_params,
        body_params: @body_params,
        result_is_list?: false
      }
    end
  end

  defmodule HandleBpmnError do
    @behaviour Cain.Rest.Endpoint

    @path_params id: :string

    @body_params [
      error_code: :string,
      error_message: :string,
      variables: :variables
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/task/{id}/bpmnError",
        method: :post,
        path_params: @path_params,
        body_params: @body_params,
        result_is_list?: false
      }
    end
  end
end
