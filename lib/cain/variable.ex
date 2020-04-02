defmodule Cain.Variable do
  # @complex_types [
  #   :file,
  #   :object,
  #   :json,
  #   :xml
  # ]

  @type variable :: %{optional(atom()) => any()} | %{}

  # @byte_precision -128..127
  @short_precision -32_768..32_767
  @integer_precision -2_147_483_648..2_147_483_647
  @long_precision -9_223_372_036_854_775_808..9_223_372_036_854_775_807

  def cast(%{__struct__: _struct} = variables) do
    cast(Map.from_struct(variables))
  end

  def cast(variables) when is_map(variables) do
    variables
    |> Map.to_list()
    |> cast()
    |> Map.new()
  end

  def cast(list, acc \\ [])

  def cast([], acc), do: acc

  def cast([{name, %DateTime{} = date_time} | rest], acc) do
    cast(rest, [
      {Atom.to_string(name), %{"type" => "Date", "value" => cast_date(date_time)}}
      | acc
    ])
  end

  def cast([{name, %Date{} = date} | rest], acc) do
    cast(rest, [
      {Atom.to_string(name), %{"type" => "Date", "value" => cast_date(date)}} | acc
    ])
  end

  def cast([{name, value} | rest], acc) when is_map(value) or is_list(value) do
    cast(rest, [
      {Atom.to_string(name), %{"type" => "Json", "value" => Jason.encode!(value)}} | acc
    ])
  end

  def cast([{name, value} | rest], acc) do
    cast(rest, [{Atom.to_string(name), %{"type" => type(value), "value" => value}} | acc])
  end

  def parse(variables) when is_map(variables) do
    variables
    |> Enum.map(fn {key, variable} -> {key, __parse__(variable)} end)
    |> Map.new()
  end

  def parse(_term) do
    :error
  end

  defp __parse__(%{"value" => value, "type" => "Json"}) when is_map(value) do
    value
  end

  defp __parse__(%{"value" => value, "type" => "Json"}) do
    Jason.decode!(value)
  end

  defp __parse__(%{"value" => value, "type" => "Date"}) do
    {:ok, date_time, _} = DateTime.from_iso8601(value)
    date_time
  end

  defp __parse__(%{"value" => value, "type" => _type}) do
    value
  end

  defp type(term) when is_nil(term), do: "Null"
  defp type(term) when is_binary(term), do: "String"
  defp type(term) when is_boolean(term), do: "Boolean"
  defp type(term) when is_float(term), do: "Double"

  # defp type(term) when is_number(term) and term in @byte_precision, do: "Byte"
  defp type(term) when is_number(term) and term in @short_precision, do: "Short"
  defp type(term) when is_number(term) and term in @integer_precision, do: "Integer"
  defp type(term) when is_number(term) and term in @long_precision, do: "Long"

  def format_milliseconds(%DateTime{microsecond: {ms, 0}} = date_time) do
    opts =
      Map.from_struct(date_time)
      |> Map.put(:microsecond, {ms, 3})
      |> Map.to_list()

    struct(DateTime, opts)
  end

  def format_milliseconds(date_time) do
    DateTime.truncate(date_time, :millisecond)
  end

  def cast_date(%DateTime{utc_offset: utc_offset} = date_time) do
    date_time
    |> format_milliseconds()
    |> DateTime.to_iso8601()
    |> format_utc_offset(utc_offset)
  end

  def cast_date(%Date{} = date) do
    IO.iodata_to_binary([Date.to_iso8601(date), "T00:00:00.000+0000"])
  end

  defp format_utc_offset(iso_string, 0) do
    String.replace(iso_string, "Z", "+0000")
  end

  defp format_utc_offset(iso_string, utc_offset) do
    h =
      div(utc_offset, 60)
      |> div(60)

    String.replace(iso_string, "Z", "+0#{h}00")
  end
end
