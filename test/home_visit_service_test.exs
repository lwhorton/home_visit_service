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
    test "create_user returns the id" do
      res = Sut.execute({:create_user, %{
        name: "Luke",
        surname: "Horton",
        email: "email@gmail.com",
        roles: MapSet.new(["member", "pal"])
      }})

      assert not is_nil(res)
    end

     test "cant create user with identical emails" do
       assert_raise Ecto.ConstraintError, fn ->

      _ins_1 = Sut.execute({:create_user, %{
        name: "Luke",
        surname: "Horton",
        email: "email@gmail.com",
        roles: MapSet.new(["member", "pal"])
      }})

      _ins_2 = Sut.execute({:create_user, %{
        name: "Luke",
        surname: "Horton",
        email: "email@gmail.com",
        roles: MapSet.new(["member", "pal"])
      }})

       end
     end
  end

  describe "validate" do
    test "validates and structures args" do
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

      res =
        Sut.parse(argv)
        |> Sut.validate(fn ->
          :halted
        end)

      roles = MapSet.new(["member", "pal"])
      assert {:ok,
              {:create_user,
               %{
                 name: "Luke",
                 surname: "Horton",
                 email: "accumulatingspam@gmail.com",
                 roles: ^roles
               }}} = res
    end

    test "exits on missing/invalid args" do
      {result, log} =
        with_log(fn ->
          argv = [
            "--create-user"
          ]

          Sut.parse(argv)
          |> Sut.validate(fn ->
            :halted
          end)
        end)

      # assert {:create_user, %{create_user: true,
      # name: "Luke", surname: "Horton", email: "accumulatingspam@gmail.com", roles: ["member", "pal"]}} = res
      assert result == :halted
      assert log =~ "create_user has missing"
    end
  end

  describe "parse" do
    test "can parse create-user" do
      argv = [
        "--create-user"
      ]

      res = Sut.parse(argv)
      assert {:create_user, _} = res
    end
  end

  describe "route" do
  end
end
