defmodule HomeVisitService.User do
  use Ecto.Schema

  schema "users" do
    field(:name, :string)
    field(:surname, :string)
    field(:email, :string)
    field(:account_id, :id)
    field(:roles, :binary)
    field(:balance_minutes, :integer)
  end
end

defmodule HomeVisitService.VisitSolicitation do
  use Ecto.Schema

  schema "visit_solicitations" do
    field(:solicitor, :id)
    field(:commencement, :utc_datetime)
    field(:duration_minutes, :integer)
    field(:tasks, :string)
  end
end

defmodule HomeVisitService.VisitFulfillment do
  use Ecto.Schema

  schema "visit_fulfillments" do
    field(:visit_solicitations_id, :id)
    field(:member_id, :id)
    field(:pal_id, :id)
  end
end
