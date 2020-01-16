defmodule DemoDecisionTable do
  use Cain.DecisionTable,
    definition_key: "PURCHASE_PARTICIPATION",
    input: [
      input: :string
    ]
end
