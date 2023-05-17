defmodule HomeVisitService.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  # todo: should probably make the primary keys UUIDs, not integers
  def change do
    create table(:users) do
      add(:name, :string, null: false)
      add(:surname, :string, null: false)
      add(:email, :string, null: false)
      add(:roles, :binary)
      add(:balance_minutes, :integer)
    end

    create(unique_index(:users, [:email]))

    create table(:visit_solicitations) do
      add(:solicitor, references("users"), null: false)
      add(:commencement, :utc_datetime, null: false)
      add(:duration_minutes, :integer, null: false)
      # todo: string might not be great here, 255 limit iirc
      add(:tasks, :string)
    end

    create table(:visit_fulfillments) do
      add(:visit_solicitations_id, references("visit_solicitations"), null: false)
      add(:member_id, references("users"), null: false)
      add(:pal_id, references("users"), null: false)
    end
  end
end
