defmodule DecisionTable do
  @moduledoc """
  Provides a set of operations to be used on specified decision tables which are modeled under the decision model and notation (DMN1.1) standards
  and especially considering the Camunda specs by simply adding the module via use .


  ## Implicit

      defmodule MyDecisionTable do
        use DecisionTable, implicit: true
        # code ...
      end
      iex> MyDecisionTable.evaluate(%{input_one: 1, input_two: "Input"})
      iex> [%{output_1: true}]

  Setting `implicit` to `true` while usage of this module will read the definition key from the xml data directly which is definied in a `decision-table-example.dmn`.
  This requires the  module to be named like its corresponding modeled dmn-file.

  """
  import Saxy.SimpleForm, only: [parse_string: 1]
  import Cain.Rest

  alias Cain.Rest.DecisionDefintion.{
    Get,
    GetXml,
    Evaluate
  }

  defmacro __using__(opts) do
    module = __CALLER__.module
    Module.put_attribute(module, :implicit?, opts[:implicit] || false)
    Module.put_attribute(module, :implicit_key, DecisionTable.definition_key(module))

    quote do
      @doc """
      Evalutes a Camunda decision table by a given definiton `identifier`.

      Valid identifiers are `:definition_id`, `:definition_key` or `:definition_tenant_id`.
      Calling with `:definition_tenant_id` needs `:definition_key` also being provided.
      """
      @spec evaluate(map(), keyword()) :: {:error, atom()} | any()
      def evaluate(variables, opts \\ [])

      def evaluate(variables, opts) when is_list(opts) do
        DecisionTable.__evaluate__(
          variables,
          opts ++ [{:implicit_key, @implicit_key}],
          @implicit?
        )
      end

      def get(opts \\ [])

      def get(opts) do
        DecisionTable.__get__(
          opts ++ [{:implicit_key, @implicit_key}],
          @implicit?
        )
      end

      def get_xml(opts \\ [])

      def get_xml(opts) do
        DecisionTable.__get_xml__(
          opts ++ [{:implicit_key, @implicit_key}],
          @implicit?
        )
      end
    end
  end

  defp get_params(opts) do
    id? = opts[:definition_id] || false

    key? = opts[:definition_key] || false

    tenant_id? = opts[:definition_tenant_id] || false

    params =
      cond do
        tenant_id? ->
          %{
            key: opts[:definition_key],
            tenant_id: opts[:definition_tenant_id]
          }

        key? ->
          %{key: opts[:definition_key]}

        id? ->
          %{id: opts[:definition_id]}

        true ->
          raise ArgumentError,
                "No valid decision identifier provided, expected: definition_id, definition_key or definition_tenant_id and definition_key"
      end

    params
    |> Map.values()
    |> List.first()
    |> is_binary()
    |> if do
      params
    else
      raise ArgumentError, "Expected value to be string!"
    end
  end

  def __get_xml__(opts, true) do
    call(GetXml, %{}, %{key: opts[:implicit_key]})
  end

  def __get_xml__(opts, false) do
    call(GetXml, %{}, get_params(opts))
  end

  def __get__(opts, true) do
    call(Get, %{}, %{key: opts[:implicit_key]})
  end

  def __get__(opts, false) do
    call(Get, %{}, get_params(opts))
  end

  def __evaluate__(variables, [{:implicit_key, implicit_key}], true) do
    call(Evaluate, %{variables: variables}, %{key: implicit_key})
  end

  def __evaluate__(variables, opts, false) do
    call(Evaluate, %{variables: variables}, get_params(opts))
    |> case do
      {:error, _message, ["RestException"]} -> {:error, :invalid_variables}
      {:error, _message, ["InvalidRequestException"]} -> {:error, :definition_not_found}
      ok -> ok
    end
  end

  def definition_key(module) when is_atom(module) do
    path_to_file =
      Module.split(module)
      |> List.last()
      |> Macro.underscore()
      |> Kernel.<>(".dmn")

    case File.read(__DIR__ <> "/" <> path_to_file) do
      {:ok, content} ->
        content
        |> parse_string()
        |> definition_key()

      error ->
        error
    end
  end

  def definition_key({:ok, {"definitions", _document_attr, decision_elements}}) do
    definition_key(decision_elements)
  end

  def definition_key([{"decision", decision_attr, _table_elements} | _rest]) do
    definition_key(decision_attr)
  end

  def definition_key([{"id", key} | _rest]) do
    key
  end

  def definition_key([_first | rest]) do
    definition_key(rest)
  end

  def definition_key([]) do
    {:error, :key_not_found}
  end
end
