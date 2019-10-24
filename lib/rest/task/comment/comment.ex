defmodule Cain.Rest.Task.Comment do
  defmodule GetList do
    @behaviour Cain.Rest.Endpoint

    @path_params id: :string

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/task/{id}/comment",
        method: :get,
        path_params: @path_params,
        result_is_list?: true
      }
    end
  end

  defmodule Get do
    @behaviour Cain.Rest.Endpoint

    @path_params id: :string, comment_id: :string

    def instructions() do
      %Cain.Rest.Endpoint{
        url_extension: "/task/{id}/comment/{commentId}",
        method: :get,
        path_params: @path_params,
        result_is_list?: true
      }
    end
  end
end
