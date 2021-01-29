defmodule Cain.RestClient do
  @moduledoc false

  @callback submit(Cain.Endpoint.request()) :: Cain.Endpoint.response()
end

defmodule Cain.RestClient.Default do
  @moduledoc false

  require Logger

  alias Cain.Endpoint.Error

  @behaviour Cain.RestClient

  @success_codes [200, 204]

  @middleware [Tesla.Middleware.JSON]

  def submit_history({method, path, query, body}) do
    submit({method, "/history" <> path, query, body})
  end

  defp client, do: Tesla.client(middleware())

  def submit({:get, path, query, _body}) do
    Tesla.get(client(), path, query: query)
    |> handle_response()
  end

  def submit({:put, path, query, body}) do
    Tesla.put(client(), path, body, query: Map.to_list(query))
    |> handle_response()
  end

  def submit({:post, path, _query, body}) do
    Tesla.post(client(), path, body)
    |> handle_response()
  end

  def submit({:delete, path, query, _body}) do
    Tesla.delete(client(), path, query: query)
    |> handle_response()
  end

  defp handle_response({:ok, %Tesla.Env{status: status, body: body}})
       when status in @success_codes do
    {:ok, body}
  end

  defp handle_response({:ok, %Tesla.Env{status: status, body: body}}) do
    Logger.error("Camunda-REST-API [#{status}] - #{body["type"]}: #{body["message"]}")
    {:error, Error.cast(status, body)}
  end

  defp handle_response({:error, reason}) when is_binary(reason) do
    {:error, Error.cast(nil, %{"type" => "Tesla", "message" => reason})}
  end

  defp handle_response({:error, reason}) do
    handle_response({:error, inspect(reason)})
  end

  defp middleware do
    conf = Application.get_env(:cain, Cain.Endpoint, [])
    url = Keyword.get(conf, :url, nil)

    if is_nil(url), do: raise("Incomplete configuration")

    [{Tesla.Middleware.BaseUrl, url} | @middleware]
  end
end
