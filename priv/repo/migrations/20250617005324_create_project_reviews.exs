defmodule Windowpane.Repo.Migrations.CreateProjectReviews do
  use Ecto.Migration

  def change do
    create table(:project_reviews) do
      add :status, :string, null: false
      add :feedback, :text
      add :project_id, references(:projects, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:project_reviews, [:project_id])
  end
end
