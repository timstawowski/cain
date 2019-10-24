defmodule Cain.Rest do
  require Logger

  defmodule Endpoint do
    @callback instructions() :: %Cain.Rest.Endpoint{}

    @enforce_keys [:url_extension, :method, :result_is_list?]
    defstruct [
      :url_extension,
      :method,
      :result_is_list?,
      :sort_keys,
      path_params: [],
      body_params: [],
      query_params: []
    ]
  end

  @middleware [
    {Tesla.Middleware.BaseUrl, "http://localhost:4004/engine-rest"},
    Tesla.Middleware.JSON
  ]

  def call(instance, body \\ %{}, path_params \\ %{}, query_params \\ [])

  def call(instance, body, path_params, query_params) do
    with %Cain.Rest.Endpoint{
           url_extension: url_extensions,
           method: method,
           result_is_list?: result_is_list?,
           sort_keys: valid_sort_keys,
           path_params: instruction_path_params,
           body_params: instruction_body_params,
           query_params: instruction_query_params
         } <-
           apply(instance, :instructions, []),
         :ok <- validate_params(instruction_path_params, path_params),
         :ok <- validate_params(instruction_body_params, body),
         :ok <- validate_params(instruction_query_params, query_params),
         :ok <- validate_sorting(valid_sort_keys, query_params),
         {:ok, casted_variables} <- cast_variables(Map.get(body, :variables, %{})),
         {:ok, endpoint} <- extract_url(url_extensions, path_params) do
      client =
        @middleware
        |> Tesla.client()

      body =
        if casted_variables != %{} do
          %{body | variables: casted_variables}
        else
          body
        end
        |> transform_body_keys()

      query = Enum.map(query_params, fn {key, value} -> {create_request_key(key), value} end)

      Logger.info(fn ->
        "Camunda call with request:\n endpoint: #{endpoint} \n method: #{method} \n body: #{
          inspect(body, pretty: true)
        } \n query: #{inspect(query, pretty: true)}"
      end)

      case method do
        :get ->
          Tesla.get!(client, endpoint, query: query)

        :put ->
          Tesla.put!(client, endpoint, body, query: query)

        :post ->
          Tesla.post!(client, endpoint, body, query: query)

        :delete ->
          Tesla.delete!(client, endpoint, query: query)
      end
      |> handle_result(result_is_list?)
    else
      error ->
        error
    end
  end

  defp handle_result(%Tesla.Env{status: status, body: response_body}, is_list?)
       when status in [200, 204] do
    Logger.info(fn ->
      "Camunda responsed successfull with:\n #{inspect(response_body, pretty: true)}"
    end)

    handle_result_body(response_body, is_list?)
  end

  defp handle_result(
         %Tesla.Env{status: status, body: %{"message" => message, "type" => type}},
         true
       ) do
    Logger.warn(fn -> "Camunda responsed with ERROR #{status}:\n [#{type}] - \"#{message}\"" end)
    {:error, message, [type]}
  end

  defp handle_result_body(response_body, true) do
    Enum.map(response_body, fn response_element ->
      handle_result_body(response_element, false)
    end)
  end

  defp handle_result_body(response_body, false) do
    Enum.reduce(response_body, %{}, fn {key, value}, acc ->
      Map.put(acc, Macro.underscore(key) |> String.to_atom(), handle_response_value(key, value))
    end)
  end

  defp handle_response_value("variables", value) do
    transform_result_vars(value)
  end

  defp handle_response_value(_key, %{"type" => _type, "value" => value}) do
    value
  end

  defp handle_response_value(_key, value) do
    value
  end

  defp transform_result_vars(variables) when is_map(variables) do
    Enum.reduce(
      variables,
      %{},
      # unhandled valueInfo
      fn {var_name,
          %{
            "type" => type,
            "value" => value,
            "valueInfo" => _value_info
          }},
         acc ->
        Map.put(
          acc,
          Macro.underscore(var_name) |> String.to_atom(),
          get_value_by_type(type, value)
        )
      end
    )
  end

  defp transform_body_keys(body) when is_map(body) and body == %{} do
    body
  end

  defp transform_body_keys(body) when is_map(body) do
    Enum.reduce(body, %{}, fn {key, value}, acc ->
      Map.put(acc, create_request_key(key), value)
    end)
  end

  def cast_variables(variables) when variables == %{} do
    {:ok, variables}
  end

  def cast_variables(variables) when is_map(variables) do
    {:ok,
     Enum.reduce(variables, %{}, fn {name, value}, acc ->
       Map.put(acc, name, cast_variable(value))
     end)}
  end

  def cast_variable(%Cain.Rest.Variable{} = variable) do
    variable
  end

  def cast_variable(value) when is_list(value) or is_map(value) do
    %{type: "Json", value: Jason.encode!(value)}
  end

  def cast_variable(value) do
    %{type: get_type_by_value(value), value: value}
  end

  defp get_type_by_value(value) when is_map(value), do: "Json"
  defp get_type_by_value(value) when is_float(value), do: "Double"
  defp get_type_by_value(value) when is_binary(value), do: "String"
  defp get_type_by_value(value) when is_integer(value), do: "Integer"
  defp get_type_by_value(value) when is_boolean(value), do: "Boolean"
  defp get_type_by_value(value), do: value

  defp get_value_by_type(type, value) when type in ["Json", "Object"], do: Jason.decode!(value)
  defp get_value_by_type(_type, value), do: value

  defp create_request_key(key) when is_atom(key) do
    {first_letter, rest} =
      Atom.to_string(key)
      |> Macro.camelize()
      |> String.Casing.titlecase_once(:default)

    {String.downcase(first_letter), rest}
    |> Tuple.to_list()
    |> IO.iodata_to_binary()
  end

  defp validate_params(_valid_params, []) do
    :ok
  end

  defp validate_params(valid_params, params) do
    Enum.map(
      params,
      fn {key, value} ->
        if Keyword.has_key?(valid_params, key) do
          type = Keyword.get(valid_params, key)

          type_check(type, value)
          |> case do
            :ok ->
              :valid

            :error ->
              {:error, "Invalid type given for '#{key}', expected type #{type}!"}
          end
        else
          {:error, "Invalid paramether given: #{key}!"}
        end
      end
    )
    |> handle_validation()
  end

  defp handle_validation(validation_result) do
    Enum.filter(
      validation_result,
      fn entry -> entry != :valid end
    )
    |> case do
      [] -> :ok
      error -> error
    end
  end

  defp validate_sorting(_valid_sort_keys, []) do
    :ok
  end

  defp validate_sorting(valid_sort_keys, sorting_params) do
    cond do
      is_nil(sorting_params[:sort_by]) and is_nil(sorting_params[:sort_order]) ->
        {:error,
         "Only a single sorting parameter specified, both sort_by and sort_order are required!"}

      not Enum.member?([:asc, :desc], sorting_params[:sort_order]) ->
        {:error, "Sort order has to be :asc for ascending or :desc for descending sorting order!"}

      not Enum.member?(valid_sort_keys, sorting_params[:sort_by]) ->
        valid_sorting_criteria =
          Enum.map(valid_sort_keys, &Atom.to_string(&1))
          |> Enum.join(", ")

        {:error,
         "Invalid sorting sort_by parameter given, has to be one of: #{valid_sorting_criteria}"}

      true ->
        :ok
    end
  end

  defp extract_url(url_set, params) when is_list(url_set) do
    {:ok,
     Enum.map(url_set, fn url ->
       replace_path_param(url, params)
     end)
     |> Enum.filter(fn url -> not String.contains?(url, ["{", "}"]) end)
     |> List.last()}
  end

  defp extract_url(url, params) do
    {:ok, replace_path_param(url, params)}
  end

  defp replace_path_param(url, params) do
    String.replace(url, ~r/(\{\w+\}*)/, fn match ->
      [_, key, _] = String.split(match, ["{", "}"])
      Map.get(params, String.to_existing_atom(key), match)
    end)
  end

  defp type_check(:string, value) when is_binary(value), do: :ok
  defp type_check(:boolean, value) when is_boolean(value), do: :ok
  defp type_check(:atom, value) when is_atom(value), do: :ok
  defp type_check(:variables, value) when is_map(value), do: :ok

  defp type_check({:array, :string}, value) when is_list(value) do
    if Enum.all?(value, fn elem -> is_binary(elem) end) do
      :ok
    else
      :error
    end
  end

  defp type_check(_type, _value), do: :error
end
