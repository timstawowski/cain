defmodule Cain.Endpoint.Error do
  defstruct [
    :type,
    :message,
    :http_status
  ]

  def cast(status, body) do
    %__MODULE__{
      type: body["type"] || "",
      message: body["message"] || "",
      http_status: status
    }
  end
end
