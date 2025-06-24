defmodule Windowpane.Repo.Migrations.PopulateInitialCreatorCuts do
  use Ecto.Migration

  def up do
    # Calculate premiere_creator_cut for projects with premiere_price
    execute """
    UPDATE projects
    SET premiere_creator_cut = CASE
      WHEN premiere_price > 0 THEN
        premiere_price - (premiere_price * (0.4 / (premiere_price + 1) + 0.1))
      ELSE 0
    END
    WHERE premiere_price IS NOT NULL AND premiere_creator_cut IS NULL
    """

    # Calculate rental_creator_cut for projects with rental_price
    execute """
    UPDATE projects
    SET rental_creator_cut = CASE
      WHEN rental_price > 0 THEN
        rental_price - (rental_price * (0.4 / (rental_price + 1) + 0.1))
      ELSE 0
    END
    WHERE rental_price IS NOT NULL AND rental_creator_cut IS NULL
    """
  end

  def down do
    # Reset creator cuts to NULL
    execute "UPDATE projects SET premiere_creator_cut = NULL, rental_creator_cut = NULL"
  end
end
