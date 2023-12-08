# ClusterEcs

Use this library to set up clustering within AWS ECS for Fargate.

## Getting started

### In AWS
Create a container port mapping (e.g. container port 7777 to host port 7777).

### In your Elixir project
Configure the libcluster topology:

```
config :libcluster,
  topologies: [
    mycluster: [
      strategy: Cluster.EcsStrategy,
      config: [
        cluster_name: "mycluster",
        service_name: "myservice",
        app_prefix: "myapp_prefix",
        region: "eu-west-1",
        container_port: 7777
      ]
    ]
  ]
```

Add libcluster to your supervision tre:

```
children = [
  ...
  {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies), [name: MyApp.ClusterSupervisor]]}
  ...
  ]
```

Configure libcluster EPMD by setting `DISTRIBUTION_PORT` in `rel/env.sh.eex`. This needs to be an env var because this EPMD module is used during startup and application configuration is not available yet:

```
export DISTRIBUTION_PORT=7777
```

Add the following line to `rel/vm.args.eex`:

```
-start_epmd false
-epmd_module Elixir.Cluster.EcsStrategy.EPMD
-kernel inet_dist_listen_min 7777
-kernel inet_dist_listen_max 7777
```

Configure (if you haven't already) `ex_aws`. The IAM user that you configure needs the following permissions:

```
ecs:ListClusters
ecs:ListServices
ecs:ListTasks
ecs:DescribeTasks
```

### Optional config

If you want to set rules for which tasks can join the cluster you can leverage the tagging features of ECS and set `match_tags` in your config:
```
config :libcluster,
  topologies: [
    mycluster: [
      strategy: Cluster.EcsStrategy,
      config: [
        ...
        match_tags: %{"deployment" => "red"}
      ]
    ]
  ]
```
This will filter out tasks which do not contain all of the tags specified in `match_tags`

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `libcluster_ecs` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:libcluster_ecs, "~> 0.2.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/libcluster_ecs>.

