defmodule Aurora.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :title, :string, null: false
      add :description, :string, null: false
      add :type, :string, null: false
      add :premiere_date, :utc_datetime, null: false
      add :premiere_price, :decimal, precision: 10, scale: 2
      add :rental_price, :decimal, precision: 10, scale: 2, null: false
      add :rental_window_hours, :integer, null: false
      add :purchase_price, :decimal, precision: 10, scale: 2, null: false
      add :status, :string, null: false, default: "draft"

      add :creator_id, references(:creators, on_delete: :restrict), null: false

      timestamps()
    end

    create index(:projects, [:creator_id])
    create index(:projects, [:type])
    create index(:projects, [:status])
    create index(:projects, [:premiere_date])
  end
end
