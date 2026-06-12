defmodule Sokochat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SokochatWeb.Telemetry,
      Sokochat.Vault,
      Sokochat.Repo,
      {Oban, Application.fetch_env!(:sokochat, Oban)},
      {DNSCluster, query: Application.get_env(:sokochat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Sokochat.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Sokochat.Finch},
      # Start a worker by calling: Sokochat.Worker.start_link(arg)
      # {Sokochat.Worker, arg},
      # Start to serve requests, typically the last entry
      SokochatWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sokochat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SokochatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
