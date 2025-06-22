defmodule Windowpane.Repo.Migrations.CreateLiveStreams do
  use Ecto.Migration

  def change do
    create table(:live_streams) do
      add :mux_stream_id, :string, null: false
      add :stream_key, :string, null: false
      add :playback_id, :string, null: false
      # Note: The asset ID of the recording will be stored in film entry which is connected through project
      add :status, :string, null: false, default: "idle"
      add :project_id, references(:projects, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:live_streams, [:project_id])
  end
end
