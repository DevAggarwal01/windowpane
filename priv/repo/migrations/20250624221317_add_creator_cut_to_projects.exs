defmodule Windowpane.Repo.Migrations.AddCreatorCutToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :creator_cut, :decimal, precision: 10, scale: 2
    end
  end
end
