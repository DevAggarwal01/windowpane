defmodule Aurora.Repo.Migrations.AddStripeAccountIdAndOnboarded do
  use Ecto.Migration

  def change do
    alter table(:creators) do
      add :stripe_account_id, :string
      add :onboarded, :boolean, default: false
    end
  end
end
