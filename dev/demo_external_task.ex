defmodule DemoExternalTask do
  def actual_work(_payload) do
    {:ok, date_time, _} = DateTime.from_iso8601("2019-04-29T14:01:47Z")
    {:bpmn_error, "303", "wrong date", %{date_time: date_time}}
  end
end
