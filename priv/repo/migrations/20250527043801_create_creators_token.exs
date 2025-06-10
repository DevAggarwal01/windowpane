defmodule Windowpane.Repo.Migrations.CreateCreatorsToken do
  use Ecto.Migration

  def change do
    create table(:creators_tokens) do
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :creator_id, references(:creators, on_delete: :delete_all), null: false

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create index(:creators_tokens, [:creator_id])
    create unique_index(:creators_tokens, [:context, :token])
  end
end
