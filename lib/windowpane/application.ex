defmodule Windowpane.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WindowpaneWeb.Telemetry,
      Windowpane.Repo,
      {DNSCluster, query: Application.get_env(:windowpane, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:windowpane, Oban)},
      {Phoenix.PubSub, name: Windowpane.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Windowpane.Finch},
      # Start a worker by calling: Windowpane.Worker.start_link(arg)
      # {Windowpane.Worker, arg},
      # Start to serve requests, typically the last entry
      WindowpaneWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Windowpane.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WindowpaneWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
