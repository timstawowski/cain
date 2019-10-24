defmodule Cain.Rest.Task.Variables do
  defmodule GetList do
    @behaviour Cain.Rest.Endpoint
    @path_params [
      id: :string
    ]

    @query_params [
      deserialized_values: :boolean
    ]

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/task/{id}/variables",
        method: :get,
        path_params: @path_params,
        query_params: @query_params,
        result_is_list?: true
      }
    end
  end
end
