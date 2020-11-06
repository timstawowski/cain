defmodule Cain.VariableTest do
  use ExUnit.Case, async: true

  import Cain.Variable

  describe "complex type casting: " do
    test "Xml" do
      assert cast(%{xml_data: "<test><case>value</case><value>string</value></test>"}) == %{
               "xml_data" => %{
                 "value" => "<test>\n\t<case>value</case>\n\t<value>string</value>\n</test>",
                 "type" => "Xml"
               }
             }

      assert cast(%{xml_data: "value"}) != %{"xml_data" => %{"value" => "value", "type" => "Xml"}}
    end

    test "Date" do
      {:ok, date} = Date.new(2007, 1, 1)
      {:ok, naiv_date_time} = NaiveDateTime.new(2019, 1, 1, 0, 0, 0)
      {:ok, date_time} = DateTime.from_naive(naiv_date_time, "Etc/UTC")

      assert cast(%{date: date}) == %{
               "date" => %{"value" => "2007-01-01T00:00:00.000+0000", "type" => "Date"}
             }

      assert cast(%{date_time: date_time}) == %{
               "date_time" => %{"value" => "2019-01-01T00:00:00.000+0000", "type" => "Date"}
             }

      assert cast(%{naiv_date_time: naiv_date_time}) == %{
               "naiv_date_time" => %{"value" => "2019-01-01T00:00:00.000+0000", "type" => "Date"}
             }
    end
  end

  describe "primitive type casting: " do
    test "String" do
      assert cast(%{string: "test"}) == %{"string" => %{"value" => "test", "type" => "String"}}
      assert cast(%{string: :test}) == %{"string" => %{"value" => "test", "type" => "String"}}
    end

    test "Null" do
      assert cast(%{none: nil}) == %{"none" => %{"value" => nil, "type" => "Null"}}
    end

    test "Double" do
      assert cast(%{double: 31.13}) == %{"double" => %{"value" => 31.13, "type" => "Double"}}
      assert cast(%{double: 31.0}) == %{"double" => %{"value" => 31.0, "type" => "Double"}}
    end

    test "Boolean" do
      assert cast(%{bool: true}) == %{"bool" => %{"value" => true, "type" => "Boolean"}}
      assert cast(%{bool: false}) == %{"bool" => %{"value" => false, "type" => "Boolean"}}
    end

    test "Integer" do
      assert cast(%{int: 1337}) == %{"int" => %{"value" => 1337, "type" => "Integer"}}
      # min_precision
      assert cast(%{int: -2_147_483_648}) == %{
               "int" => %{"value" => -2_147_483_648, "type" => "Integer"}
             }

      # max_precision
      assert cast(%{int: 2_147_483_647}) == %{
               "int" => %{"value" => 2_147_483_647, "type" => "Integer"}
             }
    end

    test "Long" do
      assert cast(%{long: 3_259_845_689}) == %{
               "long" => %{"value" => 3_259_845_689, "type" => "Long"}
             }

      # min_precision
      assert cast(%{long: -9_223_372_036_854_775_808}) == %{
               "long" => %{"value" => -9_223_372_036_854_775_808, "type" => "Long"}
             }

      # max_precision
      assert cast(%{long: 9_223_372_036_854_775_807}) == %{
               "long" => %{"value" => 9_223_372_036_854_775_807, "type" => "Long"}
             }
    end
  end
end
