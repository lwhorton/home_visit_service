import Config

config :home_visit_service, HomeVisitService.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :logger, level: :debug
