defmodule Cain.ExternalWorker.ExternalTask do
  @moduledoc """
  State of fetched external task from Camunda-BPM-REST-API.
  """

  @type t :: %__MODULE__{
          topic_name: String.t(),
          retries: non_neg_integer(),
          task: Task.t(),
          status: :running | :processed
        }
  defstruct [:topic_name, :retries, :task, status: :running]

  @spec mark_as_processed(ExternalTask.t()) :: ExternalTask.t()
  def mark_as_processed(%__MODULE__{} = external_task),
    do: %{external_task | status: :processed}
end
