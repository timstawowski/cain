defmodule Cain.Variable.Formatter do
  @moduledoc false

  # @byte_precision -128..127
  # @short_precision -32_768..32_767
  @integer_precision -2_147_483_648..2_147_483_647
  @long_precision -9_223_372_036_854_775_808..9_223_372_036_854_775_807

  @check_for_xml_content ~r/<[^>]+>/

  def __parse__(%{"value" => value, "type" => type}) when type in ["Json", "Object"],
    do: Jason.decode!(value)

  def __parse__(%{"value" => value, "type" => "Date"}) do
    {:ok, date_time, _} = DateTime.from_iso8601(value)
    date_time
  end

  def __parse__(%{"value" => value, "type" => _type}), do: value

  def __name__(term) when is_atom(term), do: Atom.to_string(term)
  def __name__(term) when is_binary(term), do: term
  def __name__(_term), do: raise Cain.Variable.InvalidNameError

  def __cast__(nil), do: %{"type" => "Null", "value" => nil}
  def __cast__(term) when is_float(term), do: %{"type" => "Double", "value" => term}

  def __cast__(term) when is_number(term) and term in @integer_precision,
    do: %{"type" => "Integer", "value" => term}

  def __cast__(term) when is_number(term) and term in @long_precision,
    do: %{"type" => "Long", "value" => term}

  def __cast__(term) when is_boolean(term), do: %{"type" => "Boolean", "value" => term}
  def __cast__(term) when is_atom(term), do: %{"type" => "String", "value" => Atom.to_string(term)}

  def __cast__(term) when is_binary(term) do
    if Regex.match?(@check_for_xml_content, term) do
      case BeautyExml.format(term) do
        {:ok, formatted_xml} ->
          %{"type" => "Xml", "value" => formatted_xml}

        :error ->
          raise Cain.Variable.InvalidXmlFormatError
      end
    else
      %{"type" => "String", "value" => term}
    end
  end

  def __cast__(%date_struct{} = date_format) when date_struct in [Date, DateTime, NaiveDateTime] do
    if date_struct == NaiveDateTime and date_format.calendar != Calendar.ISO do
      raise Cain.Variable.InvalidDateFormatError
    else
      %{"type" => "Date", "value" => cast_date(date_format)}
    end
  end

  def __cast__(value) when is_map(value) or is_list(value),
    do: %{"type" => "Json", "value" => Jason.encode!(value)}

  defp cast_date(%Date{} = date),
    do: IO.iodata_to_binary([Date.to_iso8601(date), "T00:00:00.000+0000"])

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

  defp format_milliseconds(%{__struct__: date_time_format, microsecond: {ms, 0}} = date_time) do
    opts =
      Map.from_struct(date_time)
      |> Map.put(:microsecond, {ms, 3})
      |> Map.to_list()

    struct(date_time_format, opts)
  end

  defp format_milliseconds(%{__struct__: date_time_format} = date_time_data) do
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
