defmodule HomeVisitServiceTest do
  # sqlite doesnt support async + sandboxing
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias HomeVisitService, as: Sut

  setup do
    # explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(HomeVisitService.Repo)
  end

  describe "execute" do
    test "create_user returns the whole user" do
      res =
        Sut.execute(
          {:create_user,
           %{
             name: "Luke",
             surname: "Horton",
             email: "email@gmail.com",
             roles: ["member", "pal"]
           }}
        )

      assert not is_nil(res)
      assert res.name == "Luke"
      assert res.surname == "Horton"
      assert res.email == "email@gmail.com"
      assert res.roles == ["member", "pal"]
      assert not is_nil(res.id)
    end

    test "cant create user with identical emails" do
      assert_raise Ecto.ConstraintError, fn ->
        _ins_1 =
          Sut.execute(
            {:create_user,
             %{
               name: "Luke",
               surname: "Horton",
               email: "email@gmail.com",
               roles: ["member", "pal"]
             }}
          )

        _ins_2 =
          Sut.execute(
            {:create_user,
             %{
               name: "Luke",
               surname: "Horton",
               email: "email@gmail.com",
               roles: ["member", "pal"]
             }}
          )
      end
    end

    test "grant_role adds roles to the user" do
      %{id: user_id} =
        Sut.execute(
          {:create_user,
           %{
             name: "Luke",
             surname: "Horton",
             email: "email@gmail.com",
             roles: ["member"]
           }}
        )

      res = Sut.execute({:grant_role, %{user_id: user_id, roles: ["pal"]}})
      assert user_id == res.id
      assert ["member", "pal"] == res.roles
    end

    test "get_user returns the full user, if exists" do
      %{id: user_id} =
        Sut.execute(
          {:create_user,
           %{
             name: "Luke",
             surname: "Horton",
             email: "email@gmail.com",
             roles: ["member"]
           }}
        )

      res = Sut.execute({:get_user, %{user_id: user_id}})
      assert res.name == "Luke"
      assert res.surname == "Horton"
      assert res.email == "email@gmail.com"
      assert res.roles == ["member"]
      assert res.id == user_id
    end

    test "revoke_role removes roles from the user" do
      %{id: user_id} =
        Sut.execute(
          {:create_user,
           %{
             name: "Luke",
             surname: "Horton",
             email: "email@gmail.com",
             roles: ["member", "pal"]
           }}
        )

      res = Sut.execute({:revoke_role, %{user_id: user_id, roles: ["pal"]}})
      assert res.roles == ["member"]
    end
  end

  describe "can_fulfill_visit?" do
    # todo
  end

  describe "can_solicit_visit?" do
    # todo
  end

  describe "fulfill_visit" do
    # todo: test all the failure cases (not enough balance, etc.)
    test "fulfills if a user has member role, and credits their balance, minus the overhead" do
      %{id: pal_id} =
        Sut.execute(
          {:create_user,
           %{
             name: "Luke",
             surname: "Horton",
             email: "email@gmail.com",
             roles: ["pal"],
             balance_minutes: 0
           }}
        )

      %{id: solicitor_id} =
        Sut.execute(
          {:create_user,
           %{
             name: "Bob",
             surname: "Odenkirk",
             email: "email2@gmail.com",
             roles: ["member"],
             balance_minutes: 121
           }}
        )

      solicitation =
        Sut.execute(
          {:solicit_visit,
           %{
             member_id: solicitor_id,
             duration: 120,
             commencement: ~U[2023-05-18 12:00:00Z],
             tasks: "pick up laundry, clean gutters, play cards"
           }}
        )

      fulfillment =
        Sut.execute(
          {:fulfill_visit,
           %{
             visit_solicitation_id: solicitation.id,
             pal_id: pal_id,
             fulfilled: ~U[2023-05-18 12:00:00Z]
           }}
        )

      pal = Sut.execute({:get_user, %{user_id: pal_id}})
      solicitor = Sut.execute({:get_user, %{user_id: solicitor_id}})

      # 15% fee
      assert pal.balance_minutes == 102
      assert solicitor.balance_minutes == 1
      assert fulfillment.fulfilled == ~U[2023-05-18 12:00:00Z]
      assert fulfillment.member_id == solicitor_id
      assert fulfillment.pal_id == pal_id
    end

    test "errors if visit already fulfilled" do
      %{id: pal_id} =
        Sut.execute(
          {:create_user,
           %{
             name: "Luke",
             surname: "Horton",
             email: "email@gmail.com",
             roles: ["pal"],
             balance_minutes: 0
           }}
        )

      %{id: solicitor_id} =
        Sut.execute(
          {:create_user,
           %{
             name: "Bob",
             surname: "Odenkirk",
             email: "email2@gmail.com",
             roles: ["member"],
             balance_minutes: 121
           }}
        )

      solicitation =
        Sut.execute(
          {:solicit_visit,
           %{
             member_id: solicitor_id,
             duration: 120,
             commencement: ~U[2023-05-18 12:00:00Z],
             tasks: "pick up laundry, clean gutters, play cards"
           }}
        )

      _already_fulfillment =
        Sut.execute(
          {:fulfill_visit,
           %{
             visit_solicitation_id: solicitation.id,
             pal_id: pal_id,
             fulfilled: ~U[2023-05-18 12:00:00Z]
           }}
        )

      assert {:error, reason} =
               Sut.execute(
                 {:fulfill_visit,
                  %{
                    visit_solicitation_id: solicitation.id,
                    pal_id: pal_id,
                    fulfilled: ~U[2023-05-18 12:00:00Z]
                  }}
               )

      assert reason =~ "has already been fulfilled"
    end
  end

  describe "solicit_visit" do
    test "generates a visit solicitation if a user has member role and enough
    balance" do
      %{id: user_id} =
        Sut.execute(
          {:create_user,
           %{
             name: "Luke",
             surname: "Horton",
             email: "email@gmail.com",
             roles: ["member", "pal"],
             balance_minutes: 121
           }}
        )

      res =
        Sut.execute(
          {:solicit_visit,
           %{
             member_id: user_id,
             duration: 120,
             commencement: ~U[2023-05-18 12:00:00Z],
             tasks: "pick up laundry, clean gutters, play cards"
           }}
        )

      user = Sut.execute({:get_user, %{user_id: user_id}})

      # todo: this should be better- put a hold on available balance
      assert user.balance_minutes == 121
      assert res.solicitor == user_id
      assert res.commencement == ~U[2023-05-18 12:00:00Z]
      assert res.duration_minutes == 120
      assert res.tasks == "pick up laundry, clean gutters, play cards"
    end

    test "errors if a user has no member role" do
      %{id: user_id} =
        Sut.execute(
          {:create_user,
           %{
             name: "Luke",
             surname: "Horton",
             email: "email@gmail.com",
             roles: ["pal"],
             balance_minutes: 121
           }}
        )

      assert {:error, reason} =
               Sut.execute(
                 {:solicit_visit,
                  %{
                    member_id: user_id,
                    duration: 120,
                    commencement: ~U[2023-05-18 12:00:00Z],
                    tasks: "pick up laundry, clean gutters, play cards"
                  }}
               )

      assert reason =~ "does not have the member role"
    end

    test "errors if a user is lacking enough balance" do
      %{id: user_id} =
        Sut.execute(
          {:create_user,
           %{
             name: "Luke",
             surname: "Horton",
             email: "email@gmail.com",
             roles: ["pal"],
             balance_minutes: 119
           }}
        )

      assert {:error, reason} =
               Sut.execute(
                 {:solicit_visit,
                  %{
                    member_id: user_id,
                    duration: 120,
                    commencement: ~U[2023-05-18 12:00:00Z],
                    tasks: "pick up laundry, clean gutters, play cards"
                  }}
               )

      assert reason =~ "does not have the member role"
    end
  end

  describe "parse_command!" do
    # todo: continue validating the configs and parsing for all commands
    test "exits on missing/invalid args" do
      {result, log} =
        with_log(fn ->
          argv = [
            "--create-user"
          ]

          Sut.parse_command!(
            {:create_user, Sut.create_user_cfg(), argv},
            fn ->
              :halted
            end
          )
        end)

      assert result == :halted
      assert log =~ "create_user has missing"
    end

    test "check create user" do
      argv = [
        "--create-user",
        "--name",
        "Luke",
        "--surname",
        "Horton",
        "--email",
        "accumulatingspam@gmail.com",
        "--role",
        "member",
        "--role",
        "pal"
      ]

      res = Sut.parse_command!({:create_user, Sut.create_user_cfg(), argv})

      assert {:ok,
              {:create_user,
               %{
                 name: "Luke",
                 surname: "Horton",
                 email: "accumulatingspam@gmail.com",
                 roles: ["member", "pal"]
               }}} = res
    end

    test "check grant role" do
      argv = [
        "--grant-role",
        "--user-id",
        "1",
        "--role",
        "member",
        "--role",
        "pal"
      ]

      res = Sut.parse_command!({:grant_role, Sut.grant_role_cfg(), argv})

      assert {:ok,
              {:grant_role,
               %{
                 user_id: "1",
                 roles: ["member", "pal"]
               }}} = res
    end

    test "check solicit visit" do
      argv = [
        "--solicit-visit",
        "--member-id",
        "1",
        "--duration",
        "120",
        "--commencement",
        "2023-05-18 10:00:00Z",
        "--tasks",
        "do thing, and another thing"
      ]

      res = Sut.parse_command!({:solicit_visit, Sut.solicit_visit_cfg(), argv})

      assert {:ok,
              {:solicit_visit,
               %{
                 member_id: "1",
                 duration: 120,
                 commencement: ~U[2023-05-18 10:00:00Z],
                 tasks: "do thing, and another thing"
               }}} = res
    end

    test "check fulfill visit" do
      argv = [
        "--fulfill-visit",
        "--visit-solicitation-id",
        "1",
        "--pal-id",
        "1",
        "--fulfilled",
        "2023-05-18 10:00:00Z"
      ]

      res = Sut.parse_command!({:fulfill_visit, Sut.fulfill_visit_cfg(), argv})

      assert {:ok,
              {:fulfill_visit,
               %{
                 visit_solicitation_id: "1",
                 pal_id: "1",
                 fulfilled: ~U[2023-05-18 10:00:00Z]
               }}} = res
    end
  end

  describe "parse_subcommand" do
    # todo: continue validating all subcommands
    test "can create-user" do
      argv = [
        "--create-user"
      ]

      res = Sut.parse_subcommand(argv)
      cfg = Sut.create_user_cfg()
      assert {:create_user, ^cfg, _} = res
    end

    test "can grant-role" do
      argv = [
        "--grant-role"
      ]

      res = Sut.parse_subcommand(argv)
      cfg = Sut.grant_role_cfg()
      assert {:grant_role, ^cfg, _} = res
    end
  end
end
