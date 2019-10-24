defmodule Cain.Rest.Variable do
  alias Cain.Rest.Variable

  @enforce_keys [:value, :type]
  defstruct [
    :value,
    :type,
    value_info: %{}
  ]

  def new(value, type, opts \\ [])

  def new(value, type, _opt) do
    %Variable{
      value: value,
      type: type
    }
  end
end
