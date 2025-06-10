defmodule Windowpane.Repo.Migrations.AddFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :user_role, default: "viewer", null: false
      add :plan, :string, default: "free", null: false
      add :name, :string
    end
  end
end
