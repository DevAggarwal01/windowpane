defmodule Windowpane.Repo.Migrations.RenameCreatorCutAndAddRentalCreatorCut do
  use Ecto.Migration

  def up do
    alter table(:projects) do
      # Add new premiere_creator_cut field
      add :premiere_creator_cut, :decimal, precision: 10, scale: 2

      # Add new rental_creator_cut field
      add :rental_creator_cut, :decimal, precision: 10, scale: 2
    end

    # Copy data from creator_cut to premiere_creator_cut
    execute "UPDATE projects SET premiere_creator_cut = creator_cut WHERE creator_cut IS NOT NULL"

    # Remove the old creator_cut field
    alter table(:projects) do
      remove :creator_cut
    end
  end

  def down do
    alter table(:projects) do
      # Add back the old creator_cut field
      add :creator_cut, :decimal, precision: 10, scale: 2

      # Remove the new fields
      remove :rental_creator_cut
    end

    # Copy data back from premiere_creator_cut to creator_cut
    execute "UPDATE projects SET creator_cut = premiere_creator_cut WHERE premiere_creator_cut IS NOT NULL"

    alter table(:projects) do
      remove :premiere_creator_cut
    end
  end
end
