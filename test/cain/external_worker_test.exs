defmodule TestClientMock do
  @behaviour Cain.Client

  def submit(_), do: {:ok, [%{"topicName" => "raise", "retries" => nil, "variables" => %{}}]}
end

defmodule WorkerName do
  use Cain.ExternalWorker,
    client: TestClientMock,
    polling_interval: 700

  def register_topics do
    [{:raise, {Cain.ExternalWorkerTest, :raise_crash_work, []}, []}]
  end
end

defmodule Cain.ExternalWorkerTest do
  @moduledoc false

  use ExUnit.Case, async: true

  require TestClientMock

  import ExUnit.CaptureLog

  setup do
    {:ok, task_id: "A_EX_TASK_ID", state: struct!(Cain.ExternalWorker)}
  end

  describe "init/1" do
    test "worker_id contains module name" do
      {:ok, init_state, _continue} = Cain.ExternalWorker.init(module: WorkerName)

      assert String.contains?(init_state.worker_id, "WorkerName")
    end

    test "TestClientMock is given" do
      {:ok, init_state, _continue} =
        Cain.ExternalWorker.init(module: WorkerName, client: TestClientMock)

      assert init_state.client == TestClientMock
    end
  end

  describe "handle_info/2" do
    test "unknown 'task_id' in workload leads to ignoring function result and writing log message",
         context do
      task_operation_completed_successfully = {make_ref(), {:ok, nil}}

      {:noreply, _state, {:continue, {task_id, _func_result}}} =
        Cain.ExternalWorker.handle_info(task_operation_completed_successfully, context.state)

      assert task_id == nil
    end
  end

  describe "handle_continue/2" do
    test "with retries updates retries at external task in workload", context do
      workload = %{context.task_id => %Cain.ExternalWorker.ExternalTask{retries: 10}}
      state = %{context.state | workload: workload}

      retry_instructions = {:incident, "", "", 14, 1000}

      {:noreply, updated_state, {:continue, {_task_id, request_body, _func}}} =
        Cain.ExternalWorker.handle_continue({context.task_id, retry_instructions}, state)

      updated_external_task = updated_state.workload[context.task_id]

      assert request_body["retries"] == updated_external_task.retries
      assert updated_external_task == %Cain.ExternalWorker.ExternalTask{retries: 9}
    end

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

  describe "traped Task.async/1 crash" do
    test "invokes incident" do
      worker_pid =
        start_supervised!(%{
          id: WorkerName,
          start: {WorkerName, :start_link, []},
          type: :worker
        })

      # wait for poll
      Process.sleep(1000)

      assert Process.alive?(worker_pid)

      stop_supervised(WorkerName)
    end
  end

  def raise_crash_work(_payload) do
    raise "Error"
  end
end
