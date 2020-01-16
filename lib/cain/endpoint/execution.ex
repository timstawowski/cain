defmodule Cain.Endpoint.Execution do
  def get_list(query \\ %{}) do
    {:get, "/execution", query, %{}}
  end
end
