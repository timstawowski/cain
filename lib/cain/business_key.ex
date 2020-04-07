defmodule Cain.BusinessKey do
  @type t :: String.t()
  defguard is_business_key(term) when is_binary(term)
end

defmodule Cain.BusinessKeyError do
  @moduledoc false
  defexception [:message]
end
