defmodule Windowpane.Repo.Migrations.CreateProjectApprovalQueue do
  use Ecto.Migration

  def change do
    create table(:project_approval_queue) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :inserted_at, :naive_datetime, null: false
      add :updated_at, :naive_datetime, null: false
    end

    # Add a unique index to prevent duplicate entries for the same project
    # This will also serve as a regular index for lookups
    create unique_index(:project_approval_queue, [:project_id])
  end
end
