defmodule Cain.ExternalWorkerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  defmodule WorkerName do
    use Cain.ExternalWorker

    def register_topics do
      []
    end
  end

  describe "init/1" do
    test "worker_id contains module name" do
      {:ok, init_state, _continue} = Cain.ExternalWorker.init(module: WorkerName)

      assert String.contains?(init_state.worker_id, "WorkerName")
    end
  end

  describe "handle_info/2" do
    test "unknown 'task_id' in workload leads to ignoring function result and writing log message" do
      task_operation_completed_successfully = {make_ref(), {:ok, nil}}
      state = struct!(Cain.ExternalWorker)

      {:noreply, _state, {:continue, {task_id, _func_result}}} =
        Cain.ExternalWorker.handle_info(task_operation_completed_successfully, state)

      assert task_id == nil
    end
  end

  describe "handle_continue/2" do
    test "unknown 'task_id' ignores function result and writes out log message with return type" do
      result =
        assert capture_log(fn ->
                 Cain.ExternalWorker.handle_continue({nil, {:ok, nil}}, %{})
               end)

      assert result =~ "Recieved invalid 'external_task_id' with type ':ok'"
    end

    test "invalid function result creates error log message and invokes incident" do
      result =
        assert capture_log(fn ->
                 Cain.ExternalWorker.handle_continue(
                   {"EXTERNAL_TASK_ID", {:error, :casting_failed}},
                   %{}
                 )
               end)

      assert result =~ "Recieved invalid function result for external_task_id 'EXTERNAL_TASK_ID'"
    end
  end
end
