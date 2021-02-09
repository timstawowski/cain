defmodule Cain.DecisionTable do
  @moduledoc false

  alias Cain.Endpoint.DecisionDefinition

  defmacro __using__(opts) do
    key = Keyword.get(opts, :definition_key)
    client = Keyword.get(opts, :client, Cain.Client.Default)

    if is_nil(key) do
      raise "definition_key must be provided!"
    else
      Module.put_attribute(__CALLER__.module, :key, key)
    end

    quote do
      @spec evaluate(Cain.Endpoint.strategies(), Cain.Variable.set()) :: Cain.Endpoint.response()
      def evaluate(strategy \\ {:key, @key}, body)

      def evaluate(strategy, body) do
        request_body = %{"variables" => Cain.Variable.cast(body)}

        case unquote(client).submit(DecisionDefinition.evaluate(strategy, request_body)) do
          {:ok, response} ->
            result = Enum.map(response, &Cain.Variable.parse(&1))
            {:ok, result}

          error ->
            error
        end
      end
    end
  end
end
