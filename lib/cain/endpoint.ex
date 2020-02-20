defmodule Cain.Endpoint do
  use GenServer
  require Logger

  alias Cain.Endpoint.Error

  @type request :: {:get | :post | :delete, path :: String.t(), query :: map, body :: map}

  @success_codes [200, 204]

  @middleware [
    Tesla.Middleware.JSON
    # Tesla.Middleware.Logger
  ]

  defmacro __using__(_opts) do
    quote do
      def get(path, query, body) do
        {:get, path, query, body}
        |> Cain.Endpoint.submit()
      end

      def post(path, query, body) do
        {:post, path, query, body}
        |> Cain.Endpoint.submit()
      end

      def delete(path, query, body, opts) do
        {:delete, path, query, body}
        |> Cain.Endpoint.submit(opts)
      end

      def put(path, query, body) do
        {:put, path, query, body}
        |> Cain.Endpoint.submit()
      end
    end
  end

  def submit(request, opts \\ [])

  def submit({method, path, query, body}, true) do
    {method, "/history" <> path, query, body}
  end

  def submit(request, false) do
    request
  end

  def submit(request, opts) do
    history = Keyword.get(opts, :history, false)

    GenServer.call(__MODULE__, submit(request, history))
    |> handle_response()
  end

  def start_link(args \\ []) do
    GenServer.start(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    {:ok, Tesla.client(middleware())}
  end

  def handle_call({:get, path, query, _body}, _from, state) do
    {:reply, Tesla.get(state, path, query: query), state}
  end

  def handle_call({:put, path, query, body}, _from, state) do
    {:reply, Tesla.put(state, path, body, query: query), state}
  end

  def handle_call({:post, path, _query, body}, _from, state) do
    {:reply, Tesla.post(state, path, body), state}
  end

  def handle_call({:delete, path, query, _body}, _from, state) do
    {:reply, Tesla.delete(state, path, query: query), state}
  end

  defp handle_response({:ok, %Tesla.Env{status: status, body: ""}})
       when status in @success_codes do
    :ok
  end

  defp handle_response({:ok, %Tesla.Env{status: status, body: body}})
       when status in @success_codes do
    body
  end

  defp handle_response({:ok, %Tesla.Env{status: status, body: body}}) do
    Logger.error("Camunda Response ERROR with: #{inspect(body, pretty: true)}")
    error = Error.cast(status, body)
    {:error, error.message}
  end

  defp handle_response({:error, reason}) when is_binary(reason) do
    {:error, Error.cast(nil, %{"type" => "Tesla", "message" => reason})}
  end

  defp handle_response({:error, reason}) do
    handle_response({:error, inspect(reason)})
  end

  defp middleware do
    conf = Application.get_env(:cain, __MODULE__, [])
    url = Keyword.get(conf, :url, nil)
    middleware = Keyword.get(conf, :middleware, [])

    if is_nil(url), do: raise("Incomplete configuration")

    [
      {Tesla.Middleware.BaseUrl, url},
      middleware
      | @middleware
    ]
    |> List.flatten()
  end
end
