defmodule Cain.ExternalWorker.ExternalTask do
  @moduledoc """
  State of fetched external task from Camunda-BPM-REST-API.
  """

  @type t :: %__MODULE__{
          topic_name: atom,
          retries: non_neg_integer | nil,
          task: Task.t(),
          status: :running | :processed
        }
  defstruct [:topic_name, :retries, :task, status: :running]

  @spec mark_as_processed(ExternalTask.t()) :: ExternalTask.t()
  def mark_as_processed(%__MODULE__{} = external_task),
    do: %{external_task | status: :processed}

  @spec update_retries(ExternalTask.t(), Cain.ExternalWorker.retries()) :: ExternalTask.t()
  def update_retries(%{retries: retries} = external_task, max_retries) do
    updated_retries = subtract_or_set_retries(retries, max_retries)

    %{external_task | retries: updated_retries}
  end

  defp subtract_or_set_retries(nil, max), do: max

  defp subtract_or_set_retries(current, max) when current == 0 or max == 0, do: 0

  defp subtract_or_set_retries(current, _max), do: current - 1
end
