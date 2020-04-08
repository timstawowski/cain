defmodule DemoProcess do
  use Cain.BusinessProcess,
    definition_key: "DEMO",
    # instance_timeout: 60 * 60 * 1000,
    messages: [
      "boundary_message",
      "non_intermediate_message_event",
      "intermediate_message_event"
    ]
end
