# alias Cain.Rest.Endpoint
# alias Cain.Rest
# alias Cain.Rest.Variable
# alias DecisionTable.PurchaseParticipation
# alias DecisionTable.MdcTolerance
# alias BusinessProcess.SettleClaim

# mdc = %{costEstimatePosition: %{"cost" => 242}}
# pp = %{purchasePrice: 5, purchaseParticipation: 5, pastMonthsSinceBeginningOfContract: 6}

Cain.Endpoint.start_link()
alias Cain.ProcessInstance
alias Cain.Endpoint
alias Cain.Endpoint.{ExternalTask, ProcessDefinition}

# DoStuff.start_link

a_i = %{
  "processInstanceId" => "c02717c4-1763-11ea-bb61-0242ac110004",
  "canceled" => true,
  "sortBy" => "endTime",
  "sortOrder" => "desc",
  "activityType" => "callActivity"
}

v_i = %{
  correct_device: true,
  corrected_accessories: %{},
  documents: [],
  other_device_manufacturer: nil,
  other_device_model: nil,
  other_device_model_imei: nil,
  other_device_model_serial_number: nil
}

# v_i = %{
#   estimate_of_cost: [%{"cost" => 42424, "code" => "3010"}]
# }

spec = [
  estimate_of_cost: :json
]

# GenServer.start_link(Cain.ExternalWorker,
#   topic: "price_validation",
#   polling_interval: :timer.seconds(1)
# )
eval = %{
  purchase_price: 50000,
  past_months_since_beginning_of_contract: 4,
  purchase_participation: 15000
}

demo_body = %{
  assignee: "Peter Parker",
  candidate_users: "Peter Parker, Bruce Wayne, Harvey Dent, Clark Kent",
  candidate_groups: "Repairer"
}

body = %{
  contract_nr: "data.titan_claim.contract_nr",
  brand: "data",
  model: "data",
  mediator_nr: "4865",
  deductible_amount: 5,
  max_compensation: 0,
  fair_value: 5,
  product_type: "KOMPLETTSCHUTZ_2019",
  new_device: true,
  past_months_since_beginning_of_contract: 4,
  previous_claims_count: 1,
  previous_claims_total: 4,
  forced_inspection: true,
  role_of_repairer: "stockist",
  reporter_id: 12,
  store_worker_candidates: "Peter Parker, Bruce Wayne",
  repair_stores: "5444, 56666898, 422442",
  repair_worker: "Peter Parker"
}

# DemoWorker.start_link()
# DoStuff.start_link()
