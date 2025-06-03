defmodule Aurora.Repo.Migrations.AddRoleToAdmins do
  use Ecto.Migration

  def change do
    alter table(:admins) do
      add :role, :string, default: "admin", null: false
    end

    # Create an index for faster role-based queries
    create index(:admins, [:role])
  end
end
