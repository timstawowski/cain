defmodule Cain.Endpoint.Error do
  @moduledoc false

  @type t :: %__MODULE__{
          type: String.t(),
          message: String.t(),
          http_status: String.t()
        }
  defstruct [:type, :message, :http_status]

  def cast(status, body) do
    %__MODULE__{
      type: body["type"] || "",
      message: body["message"] || "",
      http_status: status
    }
  end
end

defimpl Inspect, for: Cain.Endpoint.Error do
  def inspect(cain_error, _opts) do
    "#Cain.Error<[" <> to_string(cain_error.http_status) <> "]::" <> cain_error.type <> ">"
  end
end
