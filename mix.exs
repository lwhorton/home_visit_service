defmodule HomeVisitService.MixProject do
  use Mix.Project

  def project do
    [
      app: :home_visit_service,
      version: "0.1.0",
      elixir: "~> 1.14.4",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {HomeVisitService.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.10"},
      {:ecto_sqlite3, "~> 0.10"},
      {:burrito, github: "burrito-elixir/burrito"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  def releases do
  [
    home_visit_service: [
      steps: [:assemble, &Burrito.wrap/1],
      burrito: [
        targets: [
          macos: [os: :darwin, cpu: :x86_64],
          linux: [os: :linux, cpu: :x86_64],
          windows: [os: :windows, cpu: :x86_64]
        ],
      ]
    ]
  ]
  end
end
