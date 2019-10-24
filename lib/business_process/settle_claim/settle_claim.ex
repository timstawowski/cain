defmodule BusinessProcess.SettleClaim do
  use BusinessProcess

  @process_definition "SETTLE_CLAIM_SMARTPHONE"

  def get_current_user_task(business_key, candidate_group) do
    get_all_user_tasks(
      process_instance_business_key: business_key,
      candidate_group: candidate_group
    )
  end

  def do_visual_inspection(business_key, candidate_group, mediator_nr) do
    get_all_user_tasks(
      process_instance_business_key: business_key,
      candidate_group: candidate_group,
      name: "Visuelle Prüfung durchführen"
    )
    |> case do
      [] ->
        "No visual inspection!"

      [
        %{
          id: task_id
        }
      ] ->
        claim_user_task(task_id, mediator_nr)
        complete_user_task(task_id, %{correct_device: true})
    end
  end

  def do_technical_inspection(business_key, candidate_group, mediator_nr) do
    get_all_user_tasks(
      process_instance_business_key: business_key,
      candidate_group: candidate_group,
      name: "Technische Prüfung durchführen"
    )
    |> case do
      [] ->
        "No technical inspection!"

      [
        %{
          id: task_id
        }
      ] ->
        claim_user_task(task_id, mediator_nr)
        complete_user_task(task_id, %{warranty: false, intervention: false})
    end
  end

  def do_estimate_of_cost(business_key, candidate_group, mediator_nr) do
    get_all_user_tasks(
      process_instance_business_key: business_key,
      candidate_group: candidate_group
    )
    |> case do
      [] ->
        "No eoc!"

      [
        %{
          id: task_id
        }
      ] ->
        claim_user_task(task_id, mediator_nr)

        complete_user_task(task_id, %{
          repair_type: "repair",
          cost_estimate_positions: %{value: [%{code: "3010", cost: 16000}], type: "Json"},
          cost_estimates_total: 18000
        })
    end
  end

  def start() do
    start_process_instance_by_key(
      @process_definition,
      %{
        business_key: "999",
        with_variables_in_return: true,
        variables: %{
          reporter_id: "13",
          repairer_id: "13",
          # repair_candidates: [1, 2, 3, 4, 5, 13],
          role_of_reporter: "stockist",
          role_of_repairer: "stockist",
          contract_nr: 1337,
          brand: "SAMSUNG",
          model: "SM-G935F",
          mediator_nr: "555",
          deductible_amount: 3000,
          max_compensation: 2500,
          fair_value: 5000,
          product_type: "KOMPLETTSCHUTZ_2019",
          new_device: true,
          past_months_since_beginning_of_contract: 4,
          previous_claims_count: 0,
          previous_claims_total: 0,
          forced_inspection: false
        }
      }
    )
  end
end
