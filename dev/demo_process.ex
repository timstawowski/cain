defmodule DemoProcess do
  use Cain.BusinessProcess,
    # definition_key: "DEMO",

    definition_key: "SETTLE_CLAIM_COMMUNICATION",
    # child_definition_keys: ["IDENTIFY_SETTLEMENT_COMMUNICATION"],
    init_variables: [
      assignee: :string,
      candidate_users: :string,
      candidate_groups: :string

      # contract_nr: :string,
      # brand: :string,
      # model: :string,
      # mediator_nr: :string,
      # deductible_amount: :long,
      # max_compensation: :long,
      # fair_value: :long,
      # product_type: :string,
      # new_device: :boolean,
      # past_months_since_beginning_of_contract: :integer,
      # previous_claims_count: :integer,
      # previous_claims_total: :integer,
      # forced_inspection: :boolean,
      # role_of_repairer: :string,
      # reporter_id: :integer,
      # store_worker_candidates: :string,
      # repair_stores: :string,
      # repair_worker: :string
    ],
    forms: [
      visual_inspection: [
        correct_device: :boolean,
        corrected_accessories: :json,
        other_device_manufacturer: :string,
        other_device_model: :string,
        other_device_model_imei: :string,
        other_device_model_serial_number: :string
      ],
      technical_inspection: [
        warranty_legit: :boolean,
        defects_legit: :boolean,
        defects: :string,
        intervention: :boolean
      ],
      create_eoc: [
        repair_type: :string,
        separate_labor_cost: :boolean,
        estimate_of_cost: :json
      ],
      # invoke_inspection: [
      #   desired_state: :string,
      #   description: :string
      # ],
      purchase_participation_approval: [
        pp_approval_amount: :long
      ],
      state_transition: [
        desired_state: :string
      ]
    ]

  @code_message_name []
  def start(claim_nr, repair_worker) do
    start_instance(claim_nr, %{
      "repair_worker" => %{
        "value" => repair_worker,
        "type" => "String"
      },
      "repair_stores" => %{
        "value" => "5444, 56666898, 422442",
        "type" => "String"
      },
      "store_worker_candidates" => %{
        "value" => "Peter Parker, Bruce Wayne",
        "type" => "String"
      }
    })
    |> case do
      {:ok,
       %{
         "id" => process_instance_id,
         "variables" => %{
           "following_status" => %{"value" => following_status}
         }
       }} ->
        {:ok,
         %{
           process_instance_id: process_instance_id,
           following_status: following_status
         }}

      error ->
        error
    end
  end

  def get_following_status(business_key) do
    get_process_instance_by_business_key(business_key)
    |> case do
      {:ok, [%{"id" => process_instance_id, "ended" => false}]} ->
        nested_instances_loop(process_instance_id)
        # |> get_variables_by_process_instance
        |> get_variable_by_name("following_status", deserialized_values?: false)
        |> case do
          {:ok, %{"value" => value}} ->
            value
            |> Jason.decode!()

          error ->
            error
        end

      error ->
        error
    end
  end

  def trigger_contradiction(claim_nr, message_name) do
    correlate_message(message_name, {:business_key, claim_nr})
  end

  defp nested_instances_loop(process_instance_id) do
    process_instance_id
    |> get_current_process_instance()
    |> case do
      {:ok, []} ->
        process_instance_id

      {:ok, process_instances} ->
        process_instances
        |> Enum.filter(&(Map.get(&1, "ended") == false))
        |> List.first()
        |> Map.get("id")
        |> nested_instances_loop()

      error ->
        error
    end
  end

  def state_transition(business_key, continuation_code) do
    complete_user_task(
      business_key,
      %{
        "continuation_code" => %{"value" => continuation_code, "Type" => "String"}
      }
      # with_variables_in_return?: true
    )

    # %{
    #   "messageName" =>
    #     activity_instance["childActivityInstances"] |> List.first() |> Map.get("activityId"),
    #   "processVariables" => %{
    #     "continuation_code" => %{"value" => continuation_code, "type" => "String"}
    #   },
    #   "businessKey" => business_key,
    #   "all" => false,
    #   "resultEnabled" => true,
    #   "variablesInResultEnabled" => true
    # }
    # |> invoke_message_correlation()
  end
end
