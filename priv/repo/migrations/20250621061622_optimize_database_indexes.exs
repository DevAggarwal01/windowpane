defmodule Windowpane.Repo.Migrations.OptimizeDatabaseIndexes do
  use Ecto.Migration

  def change do
    # Remove unnecessary indexes from project_approval_queue
    drop index(:project_approval_queue, [:project_id])

    # Remove unnecessary indexes from projects
    drop index(:projects, [:status])
    drop index(:projects, [:type])

    # Remove unnecessary indexes from admins
    drop index(:admins, [:role])

    # Remove unnecessary indexes from creator_codes
    drop index(:creator_codes, [:code])

    # Remove unnecessary indexes from ownership_records
    drop index(:ownership_records, [:project_id])
    drop index(:ownership_records, [:user_id])

    # Drop status column from ownership_records (using runtime expires_at comparison instead)
    alter table(:ownership_records) do
      remove :status
    end

    # Keep these essential indexes (already exist):
    # - unique_index(:ownership_records, [:user_id, :project_id]) - prevents duplicates + handles user+project queries
    # - index(:ownership_records, [:expires_at]) - for expiration filtering
    # - index(:projects, [:creator_id]) - for creator's project listings
    # - index(:projects, [:premiere_date]) - for chronological ordering
    # - index(:project_reviews, [:project_id]) - for project feedback display
    # - unique_index(:films, [:project_id]) - for 1:1 project-film relationship
    # - unique_index(:users, [:email]) - for authentication
    # - unique_index(:creators, [:email]) - for authentication
    # - unique_index(:admins, [:email]) - for authentication
  end
end
