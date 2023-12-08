defmodule Cluster.EcsStrategy.ClusterInfo do
  @moduledoc """
  The goal of this module is to get us the following information:

  %{node_name => {{127,0,0,1} = ip, port}}

  for all the nodes in our ECS cluster.
  """

  require Logger

  @namespace "AmazonEC2ContainerServiceV20141113"

  def get_nodes(config) do
    region = Keyword.fetch!(config, :region)
    cluster_name = Keyword.fetch!(config, :cluster_name)
    service_name = Keyword.fetch!(config, :service_name)
    app_prefix = Keyword.fetch!(config, :app_prefix)
    container_port = Keyword.fetch!(config, :container_port)

    # Optional config
    match_tags = Keyword.get(config, :match_tags)

    with {:ok, task_arns} <- get_task_arns(cluster_name, region, service_name),
         {:ok, tasks} <- describe_tasks(cluster_name, task_arns, region),
         {:ok, tasks} <- filter_tasks(tasks, match_tags),
         ip_addresses <- get_ip_addresses(tasks) do
      ip_addresses_to_nodes(ip_addresses, app_prefix, container_port)
    else
      err ->
        Logger.error(fn -> "Error #{inspect(err)} while determining nodes in cluster via ECS" end)

        %{}
    end
  end

  defp get_task_arns(cluster_name, region, service_name) do
    params = %{
      "cluster" => cluster_name,
      "serviceName" => service_name,
      "desiredStatus" => "RUNNING"
    }

    "ListTasks"
    |> query(params)
    |> ExAws.request(region: region)
    |> log_aws("ListTasks")
    |> case do
      {:ok, %{"taskArns" => arns}} -> {:ok, arns}
      {:ok, _} -> {:error, "unknown task arns response"}
      error -> error
    end
  end

  defp describe_tasks(cluster_name, task_arns, region) do
    params = %{
      "cluster" => cluster_name,
      "include" => ["TAGS"],
      "tasks" => task_arns
    }

    "DescribeTasks"
    |> query(params)
    |> ExAws.request(region: region)
    |> log_aws("DescribeTasks")
    |> case do
      {:ok, %{"tasks" => tasks}} -> {:ok, tasks}
      {:ok, _} -> {:error, "unknown describe tasks response"}
      error -> error
    end
  end

  defp filter_tasks(tasks, nil) do
    {:ok, tasks}
  end

  defp filter_tasks(tasks, match_tags) do
    match_tags_set =
      match_tags
      |> Enum.map(fn {key, value} -> %{"key" => key, "value" => value} end)
      |> MapSet.new()

    filtered_tasks =
      tasks
      |> Enum.filter(fn task ->
        tags =
          task
          |> Map.get("tags", [])
          |> MapSet.new()

        MapSet.subset?(match_tags_set, tags)
      end)

    {:ok, filtered_tasks}
  end

  defp get_ip_addresses(tasks) do
    tasks
    |> Enum.filter(fn
      %{"healthStatus" => "HEALTHY", "lastStatus" => "RUNNING"} -> true
      _ -> false
    end)
    |> Enum.flat_map(&Map.get(&1, "containers", []))
    |> Enum.map(&get_container_ip_address(&1))
    |> Enum.reject(&is_nil(&1))
  end

  defp ip_addresses_to_nodes(ip_addresses, app_prefix, container_port) do
    Map.new(ip_addresses, fn ip_address_str ->
      ip_address =
        ip_address_str
        |> String.to_charlist()
        |> :inet.parse_ipv4_address()

      {:"#{app_prefix}@#{ip_address_str}", {ip_address, container_port}}
    end)
  end

  defp get_container_ip_address(%{"networkInterfaces" => [%{"privateIpv4Address" => ip_address}]}) do
    ip_address
  end

  defp get_container_ip_address(_), do: nil

  defp query(action, params) do
    ExAws.Operation.JSON.new(
      :ecs,
      %{
        data: params,
        headers: [
          {"accept-encoding", "identity"},
          {"x-amz-target", "#{@namespace}.#{action}"},
          {"content-type", "application/x-amz-json-1.1"}
        ]
      }
    )
  end

  defp log_aws(response, request_type) do
    Logger.debug("ExAws #{request_type} response: #{inspect(response)}")
    response
  end
end
