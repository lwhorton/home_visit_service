import Config

config :home_visit_service, HomeVisitService.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :logger, level: :info

config :home_visit_service, :IO, HomeVisitService.Test.CLI
