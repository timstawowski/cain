defmodule CainTest do
  use ExUnit.Case
  doctest Cain

  test "Get all process definitions" do
    assert Cain.Rest.call(Cain.Rest.Task.GetList)
  end
end
