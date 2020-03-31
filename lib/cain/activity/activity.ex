defprotocol Cain.ActivityByType do
  def get(term)
end

defimpl Cain.ActivityByType, for: Cain.ProcessInstance.ActivityInstance do
  def get(%{
        activity_type: "userTask",
        name: name,
        parent_activity_instance_id: parent_activity_instance_id
      }) do
    Cain.Endpoint.Task.get_list(%{
      "processInstanceId" => parent_activity_instance_id,
      "name" => name
    })
    |> List.first()
    |> Cain.UserTask.State.cast()
    |> Cain.UserTask.cast()
  end
end

defmodule Cain.Activity do
  import Cain.Request.Helper
  import Cain.Response.Helper

  defmacro __using__(opts) do
    extentional_fields = Keyword.get(opts, :extentional_fields)

    quote do
      def cast(params, opts \\ [])

      def cast(params, []) do
        struct(__MODULE__, pre_cast(params))
      end

      def cast(params, opts) do
        extend = Keyword.get(opts, :extend)

        struct(__MODULE__, pre_cast(params))
        |> Cain.Activity.__extend__(unquote(extentional_fields), extend)
      end

      def get_extentional_fields, do: Keyword.keys(unquote(extentional_fields))
    end
  end

  def __extend__(activity, _extentional_fields, nil) do
    activity
  end

  def __extend__(activity, extentional_fields, :full) do
    __extend__(activity, extentional_fields, only: Keyword.keys(extentional_fields))
  end

  def __extend__(activity, extentional_fields, only: only) do
    extentions =
      cond do
        is_atom(only) ->
          Keyword.take(extentional_fields, [only])

        is_list(only) && Keyword.keyword?(only) ->
          Keyword.take(extentional_fields, Keyword.keys(only))

        is_list(only) ->
          Keyword.take(extentional_fields, only)
      end

    Enum.reduce(extentions, activity, fn {field, func}, activity ->
      func_info = Function.info(func)

      Map.put(
        activity,
        field,
        if func_info[:arity] == 1 do
          func.(activity.id)
        else
          func.(
            activity.id,
            pre_cast_query(only[field])
          )
          |> variables_in_return(true)
        end
      )
    end)
  end
end
