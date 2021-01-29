defmodule Cain.ExternalWorker.ExternalTaskTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Cain.ExternalWorker.ExternalTask

  test "mark_as_processed/1 marks given ExternalTask as processed" do
    ex_task = struct!(ExternalTask)

    assert ex_task.status == :running

    ex_task_is_marked_as_processed = ExternalTask.mark_as_processed(ex_task)

    assert ex_task_is_marked_as_processed.status == :processed
  end

  describe "update_retries/2" do
    test "returns ExternalTask with given max amount of retires if ExternalTask.retries is 'nil'" do
      max_retries = 4
      ex_task = struct!(ExternalTask)

      external_task_with_max_amount_of_retries = ExternalTask.update_retries(ex_task, max_retries)
      assert external_task_with_max_amount_of_retries
    end

    test "returns ExternalTask with subtratet retries by one if ExternalTask.retries is greater than zero" do
      max_retries = 4
      ex_task = struct!(ExternalTask, retries: max_retries)

      ex_trak_with_subtracted_retres_by_one = ExternalTask.update_retries(ex_task, max_retries)
      assert ex_trak_with_subtracted_retres_by_one.retries == max_retries - 1
    end

    test "returns ExternalTask with zero retries if given max amount of retries is zero" do
      max_retries = 0
      ex_task = struct!(ExternalTask)

      ex_task_with_zero_retries = ExternalTask.update_retries(ex_task, max_retries)
      assert ex_task_with_zero_retries.retries == max_retries
    end
  end
end
