defmodule Cain.ProcessInstance.ActivityInstance.Registry do
  use GenServer

  # API

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def registered do
    GenServer.call(__MODULE__, {:registered})
  end

  def whereis_name(definition_id) do
    GenServer.call(__MODULE__, {:whereis_name, definition_id})
  end

  def register_name(definition_id, pid) do
    GenServer.call(__MODULE__, {:register_name, definition_id, pid})
  end

  def unregister_name(definition_id) do
    GenServer.cast(__MODULE__, {:unregister_name, definition_id})
  end

  def send(definition_id, process_instance) do
    case whereis_name(definition_id) do
      :undefined ->
        {:badarg, {definition_id, process_instance}}

      pid ->
        Kernel.send(pid, process_instance)
        pid
    end
  end

  # SERVER

  def init(_) do
    {:ok, Map.new()}
  end

  def handle_call({:registered}, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:whereis_name, definition_id}, _from, state) do
    {:reply, Map.get(state, definition_id, :undefined), state}
  end

  def handle_call({:register_name, definition_id, pid}, _from, state) do
    case Map.get(state, definition_id) do
      nil ->
        Process.monitor(pid)
        {:reply, :yes, Map.put(state, definition_id, pid)}

      _ ->
        {:reply, :no, state}
    end
  end

  def handle_info({:DOWN, _, :process, pid, _}, state) do
    {:noreply, remove_pid(state, pid)}
  end

  def remove_pid(state, pid_to_remove) do
    remove = fn {_key, pid} -> pid != pid_to_remove end
    Enum.filter(state, remove) |> Enum.into(%{})
  end
end
