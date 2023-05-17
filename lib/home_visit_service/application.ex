defmodule HomeVisitService.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HomeVisitService.Repo
    ]

    # https://hexdocs.pm/elixir/Supervisor.html
    opts = [strategy: :one_for_one, name: HomeVisitService.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
