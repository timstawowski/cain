defmodule Cain.Variable do
  # @complex_types [
  #   :file,
  #   :object,
  #   :json,
  #   :xml
  # ]

  # @byte_precision -128..127
  # @short_precision -32_768..32_767
  @integer_precision -2_147_483_648..2_147_483_647
  @long_precision -9_223_372_036_854_775_808..9_223_372_036_854_775_807

  @check_for_xml_content ~r/<[^>]+>/

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

  def cast([{name, %NaiveDateTime{calendar: Calendar.ISO} = naive_date_time} | rest], acc) do
    cast(rest, [
      {Atom.to_string(name), %{"type" => "Date", "value" => cast_date(naive_date_time)}} | acc
    ])
  end

  def cast([{name, %NaiveDateTime{}} | rest], acc) do
    cast(rest, [
      {Atom.to_string(name), {:error, :only_iso_calendar_supported}} | acc
    ])
  end

  def cast([{name, value} | rest], acc) when is_map(value) or is_list(value) do
    cast(rest, [
      {Atom.to_string(name), %{"type" => "Json", "value" => Jason.encode!(value)}} | acc
    ])
  end

  def cast([{name, value} | rest], acc)
      when is_boolean(value)
      when is_nil(value) do
    cast(rest, [{Atom.to_string(name), %{"type" => type(value), "value" => value}} | acc])
  end

  def cast([{name, value} | rest], acc) when is_atom(value) do
    cast(rest, [
      {Atom.to_string(name), %{"type" => "String", "value" => Atom.to_string(value)}} | acc
    ])
  end

  def cast([{name, value} | rest], acc) do
    cast(rest, [
      {Atom.to_string(name), %{"type" => type(value), "value" => value}} | acc
    ])
  end

  def parse(variables) when is_map(variables) do
    variables
    |> Enum.map(fn {key, variable} -> {key, __parse__(variable)} end)
    |> Map.new()
  end

  def parse(_term) do
    :error
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
  defp type(term) when is_float(term), do: "Double"
  defp type(term) when is_boolean(term), do: "Boolean"
  defp type(term) when is_binary(term), do: evaluate_binary(term)

  # defp type(term) when is_number(term) and term in @byte_precision, do: "Byte"
  # defp type(term) when is_number(term) and term in @short_precision, do: "Short"
  defp type(term) when is_number(term) and term in @integer_precision, do: "Integer"
  defp type(term) when is_number(term) and term in @long_precision, do: "Long"

  defp evaluate_binary(term) do
    if Regex.match?(@check_for_xml_content, term) do
      "Xml"
    else
      "String"
    end
  end

  defp cast_date(%Date{} = date) do
    IO.iodata_to_binary([Date.to_iso8601(date), "T00:00:00.000+0000"])
  end

  defp cast_date(%{__struct__: date_time_format} = date_time) do
    case format_milliseconds(date_time) do
      :error ->
        {:error, :invalid_date}

      formattd_date_time ->
        iso_date = apply(date_time_format, :to_iso8601, [formattd_date_time])

        if String.contains?(iso_date, "Z") do
          format_utc_offset(iso_date, date_time.utc_offset)
        else
          format_utc_offset(iso_date <> "Z", 0)
        end
    end
  end

  def format_milliseconds(%{__struct__: date_time_format, microsecond: {ms, 0}} = date_time) do
    opts =
      Map.from_struct(date_time)
      |> Map.put(:microsecond, {ms, 3})
      |> Map.to_list()

    struct(date_time_format, opts)
  end

  def format_milliseconds(%{__struct__: date_time_format} = date_time_data) do
    apply(date_time_format, :truncate, [date_time_data, :millisecond])
  end

  defp format_utc_offset(iso_string, 0) do
    String.replace(iso_string, "Z", "+0000")
  end

  defp format_utc_offset(iso_string, utc_offset) do
    h =
      utc_offset
      |> div(60)
      |> div(60)

    String.replace(iso_string, "Z", "+0#{h}00")
  end
end
