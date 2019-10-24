defmodule BusinessProcess do
  import Cain.Rest

  alias(Cain.Rest.{Task, ProcessDefinition})

  defmacro __using__(_) do
    quote do
      def start_process_instance_by_id(id, payload) do
        call(
          ProcessDefinition.StartProcessInstance,
          payload,
          %{id: id}
        )
      end

      def start_process_instance_by_key(key, payload) do
        call(
          ProcessDefinition.StartProcessInstance,
          payload,
          %{key: key}
        )
      end

      def start_process_instance_by_tenant(key, tenant_id, payload) do
        call(
          ProcessDefinition.StartProcessInstance,
          payload,
          %{key: key, tenant_id: tenant_id}
        )
      end

      def claim_user_task(task_id, user_id) do
        call(Task.Claim, %{user_id: user_id}, %{id: task_id}, [])
      end

      def get_process_definitions(query_params \\ []) when is_list(query_params) do
        call(ProcessDefinition.GetList, %{}, %{}, query_params)
      end

      def get_all_user_tasks(query_params \\ []) do
        call(Task.GetList, %{}, %{}, query_params)
      end

      def complete_user_task(id, variables \\ %{}) do
        call(Complete, %{variables: variables}, %{id: id})
      end
    end
  end
end
