defmodule Cain.VariableTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Cain.Variable

  describe "complex type casting: " do
    test "Xml" do
      assert Variable.cast(%{xml_data: "<test><case>value</case><value>string</value></test>"}) ==
               %{
                 "xml_data" => %{
                   "value" => "<test>\n\t<case>value</case>\n\t<value>string</value>\n</test>",
                   "type" => "Xml"
                 }
               }

      assert Variable.cast(%{xml_data: "value"}) != %{
               "xml_data" => %{"value" => "value", "type" => "Xml"}
             }
    end

    test "Date" do
      {:ok, date} = Date.new(2007, 1, 1)
      {:ok, naiv_date_time} = NaiveDateTime.new(2019, 1, 1, 0, 0, 0)
      {:ok, date_time} = DateTime.from_naive(naiv_date_time, "Etc/UTC")

      assert Variable.cast(%{date: date}) == %{
               "date" => %{"value" => "2007-01-01T00:00:00.000+0000", "type" => "Date"}
             }

      assert Variable.cast(%{date_time: date_time}) == %{
               "date_time" => %{"value" => "2019-01-01T00:00:00.000+0000", "type" => "Date"}
             }

      assert Variable.cast(%{naiv_date_time: naiv_date_time}) == %{
               "naiv_date_time" => %{"value" => "2019-01-01T00:00:00.000+0000", "type" => "Date"}
             }
    end
  end

  describe "Variable.casting input" do
    test "key as atom" do
      assert Variable.cast(%{key: "test"}) == %{"key" => %{"value" => "test", "type" => "String"}}
    end

    test "key as string" do
      assert Variable.cast(%{"key" => "test"}) == %{
               "key" => %{"value" => "test", "type" => "String"}
             }
    end
  end

  describe "primitive type Variable.casting: " do
    test "String" do
      assert Variable.cast(%{string: "test"}) == %{
               "string" => %{"value" => "test", "type" => "String"}
             }

      assert Variable.cast(%{string: :test}) == %{
               "string" => %{"value" => "test", "type" => "String"}
             }
    end

    test "Null" do
      assert Variable.cast(%{none: nil}) == %{"none" => %{"value" => nil, "type" => "Null"}}
    end

    test "Double" do
      assert Variable.cast(%{double: 31.13}) == %{
               "double" => %{"value" => 31.13, "type" => "Double"}
             }

      assert Variable.cast(%{double: 31.0}) == %{
               "double" => %{"value" => 31.0, "type" => "Double"}
             }
    end

    test "Boolean" do
      assert Variable.cast(%{bool: true}) == %{"bool" => %{"value" => true, "type" => "Boolean"}}

      assert Variable.cast(%{bool: false}) == %{
               "bool" => %{"value" => false, "type" => "Boolean"}
             }
    end

    test "Integer" do
      assert Variable.cast(%{int: 1337}) == %{"int" => %{"value" => 1337, "type" => "Integer"}}
      # min_precision
      assert Variable.cast(%{int: -2_147_483_648}) == %{
               "int" => %{"value" => -2_147_483_648, "type" => "Integer"}
             }

      # max_precision
      assert Variable.cast(%{int: 2_147_483_647}) == %{
               "int" => %{"value" => 2_147_483_647, "type" => "Integer"}
             }
    end

    test "Long" do
      assert Variable.cast(%{long: 3_259_845_689}) == %{
               "long" => %{"value" => 3_259_845_689, "type" => "Long"}
             }

      # min_precision
      assert Variable.cast(%{long: -9_223_372_036_854_775_808}) == %{
               "long" => %{"value" => -9_223_372_036_854_775_808, "type" => "Long"}
             }

      # max_precision
      assert Variable.cast(%{long: 9_223_372_036_854_775_807}) == %{
               "long" => %{"value" => 9_223_372_036_854_775_807, "type" => "Long"}
             }
    end
  end

  describe "parsing" do
    test "primitiv types successfully" do
      response_variables = %{
        "string" => %{"type" => "String", "value" => "TEST"},
        "int" => %{"type" => "Integer", "value" => 111_222_333},
        "long" => %{"type" => "Long", "value" => 111_222_333},
        "bool" => %{"type" => "Boolean", "value" => false},
        "double" => %{"type" => "Double", "value" => 123.342}
      }

      assert Variable.parse(response_variables) == %{
               "string" => "TEST",
               "int" => 111_222_333,
               "long" => 111_222_333,
               "bool" => false,
               "double" => 123.342
             }
    end

    test "complex types successfully" do
      response_variables = %{
        "json" => %{"type" => "Json", "value" => "{\"TEST\":4}"},
        "json_list" => %{"type" => "Json", "value" => "[{\"TEST\":4}]"},
        "object" => %{"type" => "Object", "value" => "{\"property\":123}"}
      }

      assert Variable.parse(response_variables) == %{
               "json" => %{"TEST" => 4},
               "json_list" => [%{"TEST" => 4}],
               "object" => %{"property" => 123}
             }
    end
  end
end
