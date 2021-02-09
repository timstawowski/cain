defmodule Cain.Endpoint do
  @moduledoc false

  @type body :: map

  @type request :: {:get | :put | :post | :delete, path :: String.t(), query :: map, body}
  @type response :: {:ok, body | binary} | {:error, Cain.Endpoint.Error.t()}

  @type strategy_id :: {:id, binary}
  @type strategy_key :: {:key, binary}
  @type strategy_key_and_tenant :: {:key, binary, :tenant_id, binary}

  @type strategies :: strategy_id | strategy_key | strategy_key_and_tenant
end
