defmodule Cluster.EcsStrategy.EPMD do
  @moduledoc """
  EPMD module for ECS strategy
  """
  require Logger

  @protocol_version 5

  def start_link do
    :ignore
  end

  def register_node(_name, _port, _family) do
    {:ok, :rand.uniform(3)}
  end

  def listen_port_please(_name, _host) do
    {:ok, distribution_port()}
  end

  def port_please(_name, _ip) do
    {:port, distribution_port(), @protocol_version}
  end

  def names(_hostname) do
    {:error, :no_epmd}
  end

  defp distribution_port do
    "DISTRIBUTION_PORT"
    |> System.fetch_env!()
    |> String.to_integer()
  end
end
