defmodule Cain.Endpoint do
  @moduledoc """
  Specification for Camunda-REST information.

  See: https://docs.camunda.org/manual/latest/reference/rest/ for further information.
  """

  defmodule Body do
    @moduledoc """
    Describe response or request body information.
    """

    @type t :: %{optional(String.t()) => variables()}

    @type variables :: %{required(var_name()) => var_values()}

    @type var_name :: String.t()
    @type var_values ::
            binary()
            | atom()
            | boolean()
            | integer()
            | float()
            | map()
            | list()
  end

  @type request :: {:get | :put | :post | :delete, path :: String.t(), query :: map, Body.t()}
  @type response :: {:ok, Body.t() | binary} | {:error, Cain.Endpoint.Error.t()}

  @type strategy_id :: {:id, binary}
  @type strategy_key :: {:key, binary}
  @type strategy_key_and_tenant :: {:key, binary, :tenant_id, binary}

  @type strategies :: strategy_id | strategy_key | strategy_key_and_tenant
end
