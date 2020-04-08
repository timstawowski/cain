defmodule Cain.Application do
  use Application
  import Supervisor.Spec, only: [worker: 2, supervisor: 2]

  def start(_type, args) do
    auto_discover? = Keyword.get(args, :auto_discover, false)

    init_instances =
      if auto_discover? do
        [{Task, fn -> business_process_models() |> start_childs() end}]
      else
        []
      end

    children =
      [
        worker(Cain.Endpoint, []),
        supervisor(Cain.BusinessProcess.DynamicSupervisor, []),
        supervisor(Cain.ProcessInstance.Registry, [])
      ] ++ init_instances

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp start_childs(defintion_keys) do
    Enum.each(defintion_keys, fn defintion_key ->
      Cain.BusinessProcess.DynamicSupervisor.start_business_process(defintion_key)
      |> case do
        {:ok, _pid} -> IO.puts("Started '#{defintion_key}' process successfully")
        error -> IO.puts("Error on '#{defintion_key}' start up #{IO.inspect(error)}")
      end
    end)
  end

  defp business_process_models do
    applications = :application.loaded_applications()

    Enum.reduce(applications, [], fn {app, _desc, _version}, acc ->
      {:ok, modules} = :application.get_key(app, :modules)

      business_process? =
        Enum.any?(modules, fn m ->
          String.starts_with?(to_string(m), "Elixir.Cain.BusinessProcess.")
        end)

      case business_process? do
        false ->
          acc

        true ->
          Enum.reduce(modules, acc, fn module, acc ->
            Code.ensure_loaded(module)

            case Keyword.get(module.__info__(:functions), :__definiton_key__) do
              nil -> acc
              0 -> [apply(module, :__definiton_key__, []) | acc]
            end
          end)
      end
    end)
  end
end
