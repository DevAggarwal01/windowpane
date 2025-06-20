defmodule Windowpane.Repo.Migrations.AddWalletBalanceToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :wallet_balance, :integer, default: 0, null: false
    end
  end
end
