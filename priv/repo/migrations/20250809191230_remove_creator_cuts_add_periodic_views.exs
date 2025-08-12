defmodule Windowpane.Repo.Migrations.RemoveCreatorCutsAddPeriodicViews do
  use Ecto.Migration

  def up do
    alter table(:projects) do
      # Remove creator cut fields
      remove :premiere_creator_cut
      remove :rental_creator_cut

      # Add periodic_views field
      add :periodic_views, :integer, default: 0
    end
  end

  def down do
    alter table(:projects) do
      # Remove periodic_views field
      remove :periodic_views

      # Add back creator cut fields
      add :premiere_creator_cut, :decimal, precision: 10, scale: 2
      add :rental_creator_cut, :decimal, precision: 10, scale: 2
    end
  end
end
