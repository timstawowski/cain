defmodule Cain.Rest.ProcessDefinition do
  defmodule StartProcessInstance do
    @behaviour Cain.Rest.Endpoint

    @path_params [
      id: :string,
      key: :string,
      tenant_id: :string
    ]

    @body_parmas [
      variables: :variables,
      business_key: :string,
      case_instance_id: :string,
      start_instructions: :string,
      skip_custom_listeners: :boolean,
      skip_io_mappings: :boolean,
      with_variables_in_return: :boolean
    ]

    def instructions do
      %Cain.Rest.Endpoint{
        url_extension: [
          "/process-definition/{id}/start",
          "/process-definition/key/{key}/start",
          "/process-definition/key/{key}/tenant-id/{tenant_id}/start"
        ],
        method: :post,
        path_params: @path_params,
        body_params: @body_parmas,
        result_is_list?: false
      }
    end
  end

  defmodule GetList do
    @behaviour Cain.Rest.Endpoint

    @query_params [
      process_definition_id: :string,
      process_definition_id_in: :string,
      name: :string,
      name_like: :string,
      deplayment_id: :string,
      key: :string,
      keys_in: :string,
      key_like: :string,
      category: :string,
      category_like: :string,
      version: :string,
      latest_version: :boolean,
      resource_name: :string,
      resource_name_like: :string,
      startable_by: :string,
      active: :boolean,
      supsended: :boolean,
      incident_id: :string,
      incident_type: :string,
      incident_message: :string,
      incident_message_like: :string,
      tenant_id_in: :string,
      without_tenant_id: :string,
      include_process_definitions_without_tenant_id: :boolean,
      version_tag: :string,
      version_tag_like: :string,
      startable_in_tasklist: :boolean,
      not_startable_in_tasklist: :boolean,
      startable_permission_check: :string,
      sort_by: :string,
      sort_order: :string,
      first_result: :integer,
      max_results: :integer
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/process-definition",
        method: :get,
        query_params: @query_params,
        result_is_list?: true
      }
    end
  end
end
