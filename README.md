# Cain
Camunda-REST-API-Interpreter to handle common Camunda specific workflow use cases for a more clearly usage by hiding the REST-Calls under the hood.

### Covered

- Handle external tasks
- Invoke DMN evaluations

## External Task Client

Use `Cain.ExternalWorker` for referencing your external task function implementation in your application.

```elixir
defmodule MyWorker do
  use Cain.ExternalWorker, [
    max_tasks: 5,           # default: 3
    use_priority: true,     # default: false
    polling_interval: 1000  # default: 3000
  ]
  
end
```


Add `register_topics/1` and create a list of a tuple with the following elements:
- Name of the topic that has been given in the BPMN-Process-Model
- Function implementation with a tuple of Module, function and args the topic refers to
- Setting lock duration in milliseconds, defaults to 3000ms

```elixir
def register_topics do
  [{:my_topic, {MyTopicHandler, :handle_topic, [:my_arg], [lock_duration: 5000]}]
end
```

Response in the referenced function by using the provided API in `MyWorker`.
> Notice: The payload of a topic fetch is always provided as the first argument and needs to be considered on your function implementation

```elixir
defmodule MyTopicHandler do

  def handle_topic(payload, :my_arg) do

    do_something_with_payload(payload)

    case an_external_service_call() do
      :ok -> 
          # provide a map with atom keys to response with variables
          MyWorker.success()

      {:error, error} -> 
          MyWorker.retry("external_service_error", inspect(error), 3, 3000)

      _unexpected -> 
          MyWorker.create_incident("unexpected_error", "See the logs")
    end
  end

end
```

## DMN Evaluation

Use `Cain.DecisionTable` and set the corresponding `definition_key` of the deployed table in the engine.

```elixir
defmodule MyDecisionTable do
  use Cain.DecisionTable, definition_key: "MY_TABLE"
end
```
And evaluate.
```elixir

MyDecisionTable.evaluate(%{first: 1, second: "Second"})
# {:ok, [%{is_valid: true}]}
```

The return value depends on the output definition of the table. 

## Installation

<!-- If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `cain` to your list of dependencies in `mix.exs`: -->

```elixir
def deps do
  [
    {:cain, "~> 0.3.0"}
  ]
end
```
<!-- 
Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/cain](https://hexdocs.pm/cain). -->

