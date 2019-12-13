defmodule DemoDecisionTable do
  use Cain.DecisionTable,
    definition_key: "PURCHASE_PARTICIPATION",
    input: [
      purchase_price: :long,
      past_months_since_beginning_of_contract: :integer,
      purchase_participation: :long
    ]
end
