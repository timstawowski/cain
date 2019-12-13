defmodule Cain.DecisionTable do
  alias Cain.Endpoint
  alias Cain.Endpoint.DecisionDefinition

  defmacro __using__(params) do
    key = Keyword.get(params, :definition_key)
    input_variables = Keyword.get(params, :input)

    cond do
      is_nil(key) ->
        raise "definition_key must be provided!"

      true ->
        Module.put_attribute(__CALLER__.module, :key, key)
    end

    quote do
      def evaluate(strategy \\ %{key: @key}, body)

      def evaluate(strategy, body) do
        DecisionDefinition.evaluate(strategy, %{
          "variables" => Cain.Variable.cast(body, unquote(input_variables))
        })
        |> Endpoint.submit()
        |> case do
          {:ok, response} ->
            {:ok, response |> Enum.map(&Cain.Variable.parse(&1))}

          error ->
            error
        end
      end
    end
  end
end
