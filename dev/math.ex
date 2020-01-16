defmodule Math do
  def add(%{"variables" => %{"foo" => first_argument, "bar" => second_argument}}) do
    sum = first_argument + second_argument

    {:ok, %{"sum" => %{"type" => "Integer", "value" => sum}}}
  end
end
