defmodule Cain.Rest.Message do
  defmodule Correlate do
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
end
