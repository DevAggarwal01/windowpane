defmodule Windowpane.Repo.Migrations.CreateCreatorCodes do
  use Ecto.Migration

  def change do
    create table(:creator_codes) do
      add :code, :string, null: false
      timestamps()
    end

    create unique_index(:creator_codes, [:code])
  end
end
