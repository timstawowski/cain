defmodule Cain.Rest.DecisionDefintion do
  defmodule Evaluate do
    @moduledoc """
    Evaluates a given decision and returns the result.
    The input values of the decision have to be supplied in the request body.
    """
    @behaviour Cain.Rest.Endpoint

    @path_params [
      id: :string,
      key: :string,
      tenant_id: :string
    ]

    @body_params [
      variables: :variables
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: [
          "/decision-definition/{id}/evaluate",
          "/decision-definition/key/{key}/evaluate",
          "/decision-definition/key/{key}/tenant-id/{tenant_id}/evaluate"
        ],
        method: :post,
        path_params: @path_params,
        body_params: @body_params,
        result_is_list?: true
      }
    end
  end

  defmodule Get do
    @moduledoc """
    Retrieves a decision definition by id, according to the DecisionDefinition interface in the engine.
    """
    @behaviour Cain.Rest.Endpoint

    @path_params [
      id: :string,
      key: :string,
      tenant_id: :string
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: [
          "/decision-definition/{id}",
          "/decision-definition/key/{key}",
          "/decision-definition/key/{key}/tenant-id/{tenant_id}"
        ],
        method: :get,
        path_params: @path_params,
        result_is_list?: false
      }
    end
  end

  defmodule GetXml do
    @moduledoc """
    Retrieves the DMN XML of a decision definition.
    """
    @behaviour Cain.Rest.Endpoint

    @path_params [
      id: :string,
      key: :string,
      tenant_id: :string
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: [
          "/decision-definition/{id}/xml",
          "/decision-definition/key/{key}/xml",
          "/decision-definition/key/{key}/tenant-id/{tenant_id}/xml"
        ],
        method: :get,
        path_params: @path_params,
        result_is_list?: false
      }
    end
  end

  defmodule GetList do
    @moduledoc """
    Queries for decision definitions that fulfill given parameters.
    Parameters may be the properties of decision definitions, such as the name,
    key or version. The size of the result set can be retrieved by using the
    Get Decision Definition Count method.
    """
    @behaviour Cain.Rest.Endpoint

    @query_params [
      decision_definition_id: :string,
      decision_definition_id_in: {:array, :string},
      name: :string,
      name_like: :string,
      deployment_id: :string,
      key: :string,
      key_like: :string,
      category: :string,
      category_like: :string,
      version: :string,
      latest_version: :boolean,
      resource_name: :string,
      resource_name_like: :string,
      decision_requirements_definition_id: :string,
      decision_requirements_definition_key: :string,
      without_decision_requirements_definition: :boolean,
      tenant_id_in: {:array, :string},
      without_tenant_id: :string,
      include_decision_definitions_without_tenant_id: :boolean,
      version_tag: :string,
      sort_by: :atom,
      sort_order: :atom,
      first_result: :string,
      max_results: :string
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/decision-definition",
        method: :get,
        query_params: @query_params,
        sort_keys: [:category, :key, :id, :name, :version, :deployment_id, :tenant_id],
        result_is_list?: true
      }
    end
  end
end
