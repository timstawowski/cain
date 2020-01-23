defmodule Math do
  def add(_payload) do
    {:ok, date_time, _} = DateTime.from_iso8601("2019-04-29T14:01:47Z")
    {:ok, %{test_date_time: date_time}}
  end
end
