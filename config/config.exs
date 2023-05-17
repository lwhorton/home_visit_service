import Config

config :home_visit_service,
  ecto_repos: [HomeVisitService.Repo]

config :home_visit_service, HomeVisitService.Repo,
  database: "database.db"

import_config "#{Mix.env()}.exs"
