defmodule Windowpane.Repo.Migrations.AddDurationToFilms do
  use Ecto.Migration

  def change do
    alter table(:films) do
      add :duration, :integer, comment: "Duration in minutes"
    end
  end
end
