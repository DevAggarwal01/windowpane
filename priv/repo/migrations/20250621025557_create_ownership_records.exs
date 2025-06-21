defmodule Windowpane.Repo.Migrations.CreateOwnershipRecords do
  use Ecto.Migration

  def change do
    create table(:ownership_records) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "active"
      add :jwt_token, :text
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:ownership_records, [:user_id])
    create index(:ownership_records, [:project_id])
    create index(:ownership_records, [:status])
    create index(:ownership_records, [:expires_at])
    create unique_index(:ownership_records, [:user_id, :project_id])
  end
end
