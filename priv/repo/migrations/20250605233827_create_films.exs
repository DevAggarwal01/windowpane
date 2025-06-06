defmodule Aurora.Repo.Migrations.CreateFilms do
  use Ecto.Migration

  def change do
    create table(:films) do
      add :trailer_upload_id, :string
      add :trailer_asset_id, :string
      add :trailer_playback_id, :string
      add :film_upload_id, :string
      add :film_asset_id, :string
      add :film_playback_id, :string
      add :project_id, references(:projects, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:films, [:project_id])
  end
end
