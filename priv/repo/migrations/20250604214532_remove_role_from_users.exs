defmodule Windowpane.Repo.Migrations.RemoveRoleFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :role
    end
  end
end
