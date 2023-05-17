defmodule HomeVisitService do
  require Logger

  alias HomeVisitService.Repo

  alias HomeVisitService.User
  alias HomeVisitService.VisitSolicitation
  alias HomeVisitService.VisitFulfillment

  @moduledoc """
  Documentation for `HomeVisitService`.
  """

  @doc """

  ## Examples

      iex> HomeVisitService.hello()
      :world

  """
  def main(argv) do
    parsed = parse(argv)
    {:ok, {route, pargs}} = validate(parsed)
    execute({route, pargs})
  end

  @parse_config strict: [
                  create_user: :boolean,
                  name: :string,
                  surname: :string,
                  email: :string,
                  role: :keep
                ]

  def parse(argv) do
    {pargs, _args, invalid} = OptionParser.parse(argv, @parse_config)

    # on bad/unrecognized args, exit
    invalidate!(invalid)

    # parse the correct subcommand (and each subcommand validates itself)
    cond do
      {:ok, _} = Keyword.fetch(pargs, :create_user) ->
        {:create_user, pargs}

      {:ok, _} = Keyword.fetch(pargs, :grant_role) ->
        "role"

      {:ok, _} = Keyword.fetch(pargs, :revoke_role) ->
        "revoke"

      {:ok, _} = Keyword.fetch(pargs, :solicit_visit) ->
        "solicit"

      {:ok, _} = Keyword.fetch(pargs, :fulfill_visit) ->
        "fulfill"

      :else ->
        help!()
        halt!()
    end
  end

  def validate({:create_user, args}, halt \\ &System.halt/1) do
    # note: probably better as a macro, if we have time
    helpful!(
      :create_user,
      halt,
      fn ->
        with name <- Keyword.fetch!(args, :name),
             surname <- Keyword.fetch!(args, :surname),
             email <- Keyword.fetch!(args, :email),
             roles when is_list(roles) and length(roles) > 0 <-
               Keyword.get_values(args, :role) do
          {:ok,
           {:create_user,
            %{name: name, surname: surname, email: email, roles: Enum.into(roles, MapSet.new())}}}
        else
          err -> halt.()
        end
      end
    )
  end

  def execute({:create_user, %{name: name, surname: surname, email: email, roles: roles} = user}) do
    {:ok, inserted} =
      %User{name: name, surname: name, email: email, roles: :erlang.term_to_binary(roles)}
      |> Repo.insert()

    inserted.id
  end

  def helpful!(subcommand, halt, fun) do
    try do
      fun.()
    rescue
      e in KeyError ->
        Logger.error("#{subcommand} has missing/invalid args:")
        Logger.error(Map.take(e, [:key, :term]))
        halt.()

      _ ->
        Logger.error("#{subcommand} was invoked incorrectly.")
        halt.()
    end
  end

  def invalidate!(invalids, halt \\ &System.halt/1)

  def invalidate!(invalids, halt) when is_list(invalids) and length(invalids) > 0 do
    invalids
    |> Enum.map(fn {opt, err} ->
      Logger.error("argument error: #{opt} #{err}")
    end)

    help!()
    halt.()
  end

  def invalidate!(_, _) do
    :noop
  end

  # quick and dirty "--help" flag
  def help!() do
    config_as_string =
      Enum.reduce(@parse_config[:strict], "", fn {opt, type}, acc ->
        acc <> "\n" <> "option \"--#{opt}\" expects type: #{type}"
      end)

    Logger.error("invalid args...")
    Logger.error(config_as_string)
  end

  def halt!(halt \\ &System.halt/1), do: halt.(1)
end
