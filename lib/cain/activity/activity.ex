defmodule Cain.Activity do
  import Cain.Request.Helper
  import Cain.Response.Helper

  defmacro __using__(opts) do
    extentional_fields = Keyword.get(opts, :extentional_fields)

    quote do
      def cast(params) do
        struct(__MODULE__, pre_cast(params))
      end

      def cast(params, opts) do
        extend = Keyword.get(opts, :extend)
        query = Keyword.get(opts, :query, [])

        fields =
          case extend do
            :full ->
              unquote(extentional_fields)

            only: only ->
              filtered =
                if is_atom(only) do
                  [only]
                else
                  only
                end

              Keyword.take(unquote(extentional_fields), filtered)

            nil ->
              []
          end

        params
        |> cast
        |> Cain.Activity.__extend_cast__(fields, query)
      end

      def get_extensional_fields, do: Keyword.keys(unquote(extentional_fields))
    end
  end

  #  TODO: looks shit but works
  def __extend_cast__(activity, extentional_fields, query) do
    Enum.reduce(extentional_fields, activity, fn {field, func}, activity ->
      func_info = Function.info(func)
      arity = Keyword.get(func_info, :arity)

      Map.put(
        activity,
        field,
        if arity == 1 do
          func.(activity.id)
        else
          func.(
            activity.id,
            pre_cast_query(query)
          )
          |> variables_in_return(true)
        end
      )
    end)
  end
end
