defmodule Cain.Event do
  @moduledoc false
  @type t :: map()

  defstruct [:name, :type]

  defimpl Inspect, for: __MODULE__ do
    def inspect(event, _opts) do
      "#{event.name}"
    end
  end

  def cast(%{"eventName" => name, "eventType" => type}) do
    struct(__MODULE__, name: name, type: type)
  end
end
