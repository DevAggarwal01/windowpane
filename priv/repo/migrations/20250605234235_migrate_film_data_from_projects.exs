defmodule Windowpane.Repo.Migrations.MigrateFilmDataFromProjects do
  use Ecto.Migration
  import Ecto.Query

  def up do
    # First, run the films table creation migration if it hasn't been run yet
    flush()

    # Copy film data from projects to films table
    execute("""
      INSERT INTO films (project_id, trailer_upload_id, trailer_asset_id, trailer_playback_id, film_upload_id, film_asset_id, film_playback_id, inserted_at, updated_at)
      SELECT
        id,
        trailer_upload_id,
        trailer_asset_id,
        trailer_playback_id,
        film_upload_id,
        film_asset_id,
        film_playback_id,
        NOW(),
        NOW()
      FROM projects
      WHERE trailer_upload_id IS NOT NULL
         OR trailer_asset_id IS NOT NULL
         OR trailer_playback_id IS NOT NULL
         OR film_upload_id IS NOT NULL
         OR film_asset_id IS NOT NULL
         OR film_playback_id IS NOT NULL
    """)

    # Remove film-specific columns from projects table
    alter table(:projects) do
      remove :trailer_upload_id
      remove :trailer_asset_id
      remove :trailer_playback_id
      remove :film_upload_id
      remove :film_asset_id
      remove :film_playback_id
    end
  end

  def down do
    # Add film-specific columns back to projects table
    alter table(:projects) do
      add :trailer_upload_id, :string
      add :trailer_asset_id, :string
      add :trailer_playback_id, :string
      add :film_upload_id, :string
      add :film_asset_id, :string
      add :film_playback_id, :string
    end

    # Copy film data back from films to projects table
    execute("""
      UPDATE projects
      SET
        trailer_upload_id = films.trailer_upload_id,
        trailer_asset_id = films.trailer_asset_id,
        trailer_playback_id = films.trailer_playback_id,
        film_upload_id = films.film_upload_id,
        film_asset_id = films.film_asset_id,
        film_playback_id = films.film_playback_id
      FROM films
      WHERE projects.id = films.project_id
    """)

    # Delete all film records
    execute("DELETE FROM films")
  end
end
