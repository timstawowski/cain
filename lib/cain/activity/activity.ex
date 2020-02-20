defmodule Cain.Activity do
  import Cain.Response.Helper

  defmacro __using__(opts) do
    extentional_fields = Keyword.get(opts, :extentional_fields)

    quote do
      def cast(params) do
        struct(__MODULE__, pre_cast(params))
      end

      def cast(params, extend: :full) do
        params
        |> cast
        |> Cain.Activity.__extend_cast__(unquote(extentional_fields))
      end

      def cast(params, extend: [only: field]) when is_atom(field) do
        cast(params, extend: [only: [field]])
      end

      def cast(params, extend: [only: fields]) when is_list(fields) do
        filtered = Keyword.take(unquote(extentional_fields), fields)

        params
        |> cast
        |> Cain.Activity.__extend_cast__(filtered)
      end

      def get_extensional_fields, do: Keyword.keys(unquote(extentional_fields))
    end
  end

  def __extend_cast__(activity, extentional_fields) do
    Enum.reduce(extentional_fields, activity, fn {field, func}, activity ->
      Map.put(
        activity,
        field,
        func.(activity.id)
      )
    end)
  end
end
