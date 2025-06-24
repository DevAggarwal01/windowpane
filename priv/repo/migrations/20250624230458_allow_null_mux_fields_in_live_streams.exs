defmodule Windowpane.Repo.Migrations.AllowNullMuxFieldsInLiveStreams do
  use Ecto.Migration

  def up do
    # Allow NULL values for Mux fields since they are filled in later when the live stream is created with Mux
    alter table(:live_streams) do
      modify :mux_stream_id, :string, null: true
      modify :stream_key, :string, null: true
      modify :playback_id, :string, null: true
    end
  end

  def down do
    # Revert back to NOT NULL (this might fail if there are NULL values in the database)
    alter table(:live_streams) do
      modify :mux_stream_id, :string, null: false
      modify :stream_key, :string, null: false
      modify :playback_id, :string, null: false
    end
  end
end
