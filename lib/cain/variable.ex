defmodule Cain.Variable do
  # @types [:string, :boolean, :integer, :long, :double, :json, :object]
  @types [:string, :boolean, :integer, :long, :double, :json]

  # TODO:  types into protocol
  def valid_spec?(spec) do
    Keyword.keyword?(spec) and Enum.all?(Keyword.values(spec), &Enum.member?(@types, &1))
  end

  def parse(%{"value" => value, "type" => "Json"}) do
    Jason.decode!(value)
  end

  def parse(%{"value" => value, "type" => _type}) do
    value
  end

  def parse(variables) when is_map(variables) do
    variables
    |> Enum.map(fn {key, variable} -> {key, parse(variable)} end)
    |> Map.new()
  end

  def cast(%{}, nil) do
    %{}
  end

  def cast(term, spec) when is_map(term) and is_list(spec) do
    term
    |> Map.to_list()
    |> cast(spec)
    |> Map.new()
  end

  def cast(_term, []) do
    []
  end

  def cast([{key, value} | variables], spec) when is_binary(key) do
    atom_key = String.to_existing_atom(key)

    cast([{atom_key, value} | variables], spec)
  rescue
    ArgumentError ->
      cast(variables, spec)
  end

  def cast([{key, value} | variables], spec) when is_atom(key) and is_list(spec) do
    case Keyword.fetch(spec, key) do
      {:ok, type} ->
        [{Atom.to_string(key), cast(value, type)} | cast(variables, spec)]

      _ ->
        cast(variables, spec)
    end
  end

  def cast(value, :string) when is_binary(value) or is_nil(value) do
    %{
      "value" => value,
      "type" => "String"
    }
  end

  def cast(value, :boolean) when is_boolean(value) or is_nil(value) do
    %{
      "value" => value,
      "type" => "Boolean"
    }
  end

  def cast(value, :integer) when is_integer(value) or is_nil(value) do
    %{
      "value" => value,
      "type" => "Integer"
    }
  end

  def cast(value, :long) when is_integer(value) or is_nil(value) do
    %{
      "value" => value,
      "type" => "Long"
    }
  end

  # handle decimal?
  # def cast(%Decimal{} = decimal, :long) do

  # end

  def cast(value, :double) when is_integer(value) or is_nil(value) do
    %{
      "value" => value,
      "type" => "Double"
    }
  end

  def cast(value, :json) when is_map(value) or is_list(value) do
    %{
      "value" => Jason.encode!(value),
      "type" => "Json"
    }
  end

  def cast([], _spec) do
    []
  end

  # def cast(value, :object) do
  # end
end
