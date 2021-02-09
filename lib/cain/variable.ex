defmodule Cain.Variable do
  @moduledoc """
  Handling variable formatting for sending or receiving variable data to Camunda.
  """

  @typedoc """
  Currently supported values to handle backward and forward formatting.
  """
  @type values ::
          binary()
          | atom()
          | boolean()
          | integer()
          | float()
          | map()
          | list()
          | Date.t()
          | DateTime.t()
          | NaiveDateTime.t()

  @typedoc """
  Name of the variable.
  """
  @type name :: binary | atom

  @type set :: %{name() => values()} | struct

  @doc """
  Cast given set of variables into required Camunda-REST body format.

  Given struct, list or map value will be formatted into variable type 'Json'.
  """
  @spec cast(set) :: Cain.Endpoint.Body.variables()
  def cast(%{__struct__: _struct} = variables), do: cast(Map.from_struct(variables))

  def cast(variables) when is_map(variables) do
    variables
    Enum.reduce(variables, %{}, fn {key, value}, acc ->
      name = Cain.Variable.Formatter.__name__(key)
      Map.put(acc, name, Cain.Variable.Formatter.__cast__(value))
    end)
  end

  @doc """
  Parse given Camunda-REST response body variables.

  Type `Json` and `Object` will be decoded on receive.
  """
  @spec parse(Cain.Endpoint.Body.variables()) :: set
  def parse(variables) when is_map(variables) do
    Enum.reduce(variables, %{}, fn {key, variable}, acc ->
      Map.put(acc, key, Cain.Variable.Formatter.__parse__(variable))
    end)
  end
end
