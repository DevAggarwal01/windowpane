defmodule Windowpane.Repo.Migrations.CreatePremieres do
  use Ecto.Migration

  def change do
    create table(:premieres) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :start_time, :utc_datetime, null: false
      add :end_time, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:premieres, [:project_id])
    create index(:premieres, [:start_time])
    create index(:premieres, [:end_time])
  end
end
