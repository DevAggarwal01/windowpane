defmodule Windowpane.Repo.Migrations.RemovePurchasePriceFromProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      remove :purchase_price
    end
  end
end
