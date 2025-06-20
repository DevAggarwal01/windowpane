defmodule Windowpane.Repo.Migrations.AddWalletBalanceToCreators do
  use Ecto.Migration

  def change do
    alter table(:creators) do
      add :wallet_balance, :integer, default: 0, null: false
    end
  end
end
