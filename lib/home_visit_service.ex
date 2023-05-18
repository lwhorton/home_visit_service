defmodule HomeVisitService do
  import Ecto.Query
  require Logger

  alias HomeVisitService.Repo
  alias Ecto.Changeset

  alias HomeVisitService.User
  alias HomeVisitService.VisitSolicitation
  alias HomeVisitService.VisitFulfillment

  def main(argv \\ []) do
    {subcommand, cfg, _pargs} = parse_subcommand(argv)

    {:ok, {command, pargs}} = parse_command!({subcommand, cfg, argv})

    execute({command, pargs})
  end

  def subcommands() do
    [
      switches: [
        create_user: :boolean,
        grant_role: :boolean,
        revoke_role: :boolean,
        get_user: :boolean,
        solicit_visit: :boolean,
        fulfill_visit: :boolean,
        grant_balance: :boolean
      ]
    ]
  end

  def create_user_cfg() do
    [
      strict: [
        create_user: :boolean,
        name: :string,
        surname: :string,
        email: :string,
        role: :keep
      ]
    ]
  end

  def grant_role_cfg() do
    [
      strict: [
        grant_role: :boolean,
        user_id: :string,
        role: :keep
      ]
    ]
  end

  def revoke_role_cfg() do
    [
      strict: [
        revoke_role: :boolean,
        user_id: :string,
        role: :keep
      ]
    ]
  end

  def get_user_cfg() do
    [
      strict: [
        get_user: :boolean,
        user_id: :string
      ]
    ]
  end

  def solicit_visit_cfg() do
    [
      strict: [
        solicit_visit: :boolean,
        member_id: :string,
        duration: :integer,
        # todo: this could be a much nicer input arg (day, time, e.g.)
        commencement: :string,
        tasks: :string
      ]
    ]
  end

  def fulfill_visit_cfg() do
    [
      strict: [
        fulfill_visit: :boolean,
        visit_solicitation_id: :string,
        pal_id: :string,
        fulfilled: :string
      ]
    ]
  end

  def grant_balance_cfg() do
    [
      strict: [
        grant_balance: :boolean,
        user_id: :integer,
        balance: :integer
      ]
    ]
  end

  def parse_subcommand(argv) do
    {pargs, _args, invalid} = OptionParser.parse(argv, subcommands())

    # on bad/unrecognized subcommands, exit
    invalidate!(:subcommand, invalid)

    # parse the correct subcommand (each subcommand validates itself later)
    cond do
      Keyword.get(pargs, :create_user) ->
        {:create_user, create_user_cfg(), pargs}

      Keyword.get(pargs, :grant_role) ->
        {:grant_role, grant_role_cfg(), pargs}

      Keyword.get(pargs, :get_user) ->
        {:get_user, get_user_cfg(), pargs}

      Keyword.get(pargs, :revoke_role) ->
        {:revoke_role, revoke_role_cfg(), pargs}

      Keyword.get(pargs, :solicit_visit) ->
        {:solicit_visit, solicit_visit_cfg(), pargs}

      Keyword.get(pargs, :fulfill_visit) ->
        {:fulfill_visit, fulfill_visit_cfg(), pargs}

      Keyword.get(pargs, :grant_balance) ->
        {:grant_balance, grant_balance_cfg(), pargs}

      :else ->
        Logger.error("unrecognized command: #{argv}")
        halt!()
    end
  end

  def validate(command_and_parsed_args)

  def validate({:create_user, pargs}) do
    with name <- Keyword.fetch!(pargs, :name),
         surname <- Keyword.fetch!(pargs, :surname),
         email <- Keyword.fetch!(pargs, :email),
         roles when is_list(roles) and length(roles) > 0 <-
           Keyword.get_values(pargs, :role) do
      {:ok, {:create_user, %{name: name, surname: surname, email: email, roles: roles}}}
    end
  end

  def validate({:grant_role, pargs}) do
    with user_id <- Keyword.fetch!(pargs, :user_id),
         roles when is_list(roles) and length(roles) > 0 <-
           Keyword.get_values(pargs, :role) do
      {:ok, {:grant_role, %{user_id: user_id, roles: roles}}}
    end
  end

  def validate({:revoke_role, pargs}) do
    with user_id <- Keyword.fetch!(pargs, :user_id),
         roles when is_list(roles) and length(roles) > 0 <-
           Keyword.get_values(pargs, :role) do
      {:ok, {:revoke_role, %{user_id: user_id, roles: roles}}}
    end
  end

  def validate({:get_user, pargs}) do
    with user_id <- Keyword.fetch!(pargs, :user_id) do
      {:ok, {:get_user, %{user_id: user_id}}}
    end
  end

  def validate({:solicit_visit, pargs}) do
    with member_id <- Keyword.fetch!(pargs, :member_id),
         duration <- Keyword.fetch!(pargs, :duration),
         commencement <- Keyword.fetch!(pargs, :commencement),
         tasks <- Keyword.fetch!(pargs, :tasks),
         {:ok, dt, _offset} <- DateTime.from_iso8601(commencement) do
      {:ok,
       {:solicit_visit,
        %{member_id: member_id, duration: duration, commencement: dt, tasks: tasks}}}
    end
  end

  def validate({:fulfill_visit, pargs}) do
    with pal_id <- Keyword.fetch!(pargs, :pal_id),
         solicitation_id <- Keyword.fetch!(pargs, :visit_solicitation_id),
         fulfilled <- Keyword.fetch!(pargs, :fulfilled),
         {:ok, dt, _offset} <- DateTime.from_iso8601(fulfilled) do
      {:ok,
       {:fulfill_visit, %{pal_id: pal_id, visit_solicitation_id: solicitation_id, fulfilled: dt}}}
    end
  end

  def validate({:grant_balance, pargs}) do
    with user_id <- Keyword.fetch!(pargs, :user_id),
         balance <- Keyword.fetch!(pargs, :balance) do
      {:ok, {:grant_balance, %{user_id: user_id, balance: balance}}}
    end
  end

  def execute({:create_user, %{name: name, surname: surname, email: email, roles: roles} = user}) do
    roles = Enum.into(roles, MapSet.new())

    # todo: catch constraint errors
    {:ok, inserted} =
      %User{
        name: name,
        surname: surname,
        email: email,
        roles: :erlang.term_to_binary(roles),
        # let the db set default, but guard against nils
        balance_minutes: Map.get(user, :balance_minutes)
      }
      |> Repo.insert()

    execute({:get_user, %{user_id: inserted.id}})
  end

  def execute({:grant_role, %{user_id: user_id, roles: roles}}) do
    user = Repo.get!(User, user_id)
    existing_roles = :erlang.binary_to_term(user.roles)
    new_roles = MapSet.union(existing_roles, MapSet.new(roles)) |> :erlang.term_to_binary()

    user = Changeset.change(user, roles: new_roles)
    Repo.update!(user)
    execute({:get_user, %{user_id: user_id}})
  end

  def execute({:revoke_role, %{user_id: user_id, roles: roles}}) do
    user = Repo.get!(User, user_id)
    existing_roles = :erlang.binary_to_term(user.roles)
    new_roles = MapSet.difference(existing_roles, MapSet.new(roles)) |> :erlang.term_to_binary()

    user = Changeset.change(user, roles: new_roles)
    Repo.update!(user)
    execute({:get_user, %{user_id: user_id}})
  end

  def execute({:get_user, %{user_id: user_id}}) do
    Repo.get!(User, user_id)
    |> Map.update(:roles, [], fn r -> :erlang.binary_to_term(r) |> Enum.into([]) end)
  end

  def execute(
        {:solicit_visit,
         %{member_id: member_id, duration: duration, commencement: commencement, tasks: tasks}}
      ) do
    member = execute({:get_user, %{user_id: member_id}})

    case can_solicit_visit?(member, duration) do
      true ->
        {:ok, inserted} =
          Repo.insert(%VisitSolicitation{
            solicitor: member.id,
            commencement: commencement,
            duration_minutes: duration,
            tasks: tasks
          })

        # todo: we'd probably want better tracking around balance_minutes on
        # soliciting a visit (so you cant cash a check the bank can't handle)

        inserted

      err ->
        err
    end
  end

  def execute(
        {:fulfill_visit, %{visit_solicitation_id: visit_id, pal_id: pal_id, fulfilled: fulfilled}}
      ) do
    # todo: make sure the fulfillment isn't in the future, the pal isnt
    # fulfilling their own solicitation, etc.
    pal = execute({:get_user, %{user_id: pal_id}})

    # todo: could make this a cli command
    solicitation = Repo.get!(VisitSolicitation, visit_id)

    # todo: could also make this a cli command
    existing_fulfillment =
      Repo.one(
        from(f in VisitFulfillment,
          join: s in VisitSolicitation,
          on: f.visit_solicitations_id == s.id,
          where: f.visit_solicitations_id == ^visit_id
        )
      )

    case can_fulfill_visit?(pal, existing_fulfillment) do
      true ->
        {:ok, result} =
          Repo.transaction(fn repo ->
            # avoid a potentially nasty bug by re-fetching the user again inside
            # the transaction, even though we already have a handle on one
            pal = execute({:get_user, %{user_id: pal_id}})

            {:ok, fulfillment} =
              repo.insert(%VisitFulfillment{
                # todo: we could probably come up with a better relation model
                # around multiple member(s) fulfilling a visit, partial visits
                visit_solicitations_id: solicitation.id,
                member_id: solicitation.solicitor,
                pal_id: pal.id,
                fulfilled: fulfilled
              })

            pal =
              Changeset.change(pal,
                balance_minutes: calculate_credit_balance(pal, solicitation)
              )

            repo.update!(pal)

            member = execute({:get_user, %{user_id: solicitation.solicitor}})

            member =
              Changeset.change(member,
                balance_minutes: calculate_debit_balance(member, solicitation)
              )

            repo.update!(member)

            fulfillment
          end)

        result

      err ->
        err
    end
  end

  def execute({:grant_balance, %{user_id: user_id, balance: balance}}) do
    {:ok, result} =
      Repo.transaction(fn repo ->
        user = execute({:get_user, %{user_id: user_id}})

        change =
          Changeset.change(user,
            balance_minutes: user.balance_minutes + balance
          )

        repo.update!(change)
      end)

    result
  end

  @fee 0.15
  def calculate_credit_balance(pal, solicitation) do
    round((pal.balance_minutes + solicitation.duration_minutes) * (1 - @fee))
  end

  def calculate_debit_balance(member, solicitation) do
    member.balance_minutes - solicitation.duration_minutes
  end

  def can_solicit_visit?(%{roles: roles, balance_minutes: balance} = user, duration) do
    with {_, true} <- {:role, Enum.member?(roles, "member")},
         {_, true} <- {:balance, duration <= balance} do
      true
    else
      {:role, _} ->
        {:error, "member #{user.id} does not have the member role and cannot solicit visits"}

      {:balance, _} ->
        {:error, "member #{user.id} does not have enough balance to solicit a visit"}
    end
  end

  def can_fulfill_visit?(%{roles: roles} = user, fulfillment) do
    with {_, true} <- {:already_fulfilled, is_nil(fulfillment)},
         {_, true} <- {:role, Enum.member?(roles, "pal")} do
      true
    else
      {:already_fulfilled, _} ->
        {:error, "visit #{fulfillment.visit_solicitations_id} has already been fulfilled"}

      {:role, _} ->
        {:error, "user #{user.id} does not have the pal role and cannot fulfill visits"}
    end
  end

  def parse_command!({subcommand, cfg, argv}, halt \\ &halt!/0) do
    try do
      {pargs, _args, invalid} = OptionParser.parse(argv, cfg)

      # on bad/unrecognized config args, exit
      invalidate!(:args, invalid)

      validate({subcommand, pargs})
    rescue
      e in KeyError ->
        Logger.error("#{subcommand} has missing/invalid args:")
        Logger.error(Map.take(e, [:key, :term]))
        halt.()

      err ->
        Logger.error("#{subcommand} was invoked incorrectly: #{inspect(err)}")
        halt.()
    end
  end

  def invalidate!(module, invalids, halt \\ &halt!/0)

  def invalidate!(:subcommand, invalids, halt) when is_list(invalids) and length(invalids) > 0 do
    Logger.error("subcommand was invoked incorrectly:")
    IO.inspect(wtf: inspect(invalids))

    invalids
    |> Enum.map(fn {opt, err} ->
      Logger.error("argument error: #{opt} #{err}")
    end)

    halt.()
  end

  def invalidate!(:args, invalids, halt) when is_list(invalids) and length(invalids) > 0 do
    Logger.error("bad arguments:")

    invalids
    |> Enum.map(fn {opt, err} ->
      Logger.error("argument error: #{opt} #{err}")
    end)

    halt.()
  end

  def invalidate!(_, _, _) do
    :well_formed
  end

  def halt!() do
    Application.get_env(:home_visit_service, :IO)
  end
end

defmodule HomeVisitService.IO.Behaviour do
  @callback halt!() :: no_return()
end

defmodule HomeVisitService.CLI do
  @behaviour HomeVisitService.IO.Behaviour
  @impl true
  def halt!(), do: System.halt(1)
end

defmodule HomeVisitService.Test.CLI do
  require Logger
  @behaviour HomeVisitService.IO.Behaviour
  @impl true
  def halt!(), do: Logger.error("Halted!")
end
