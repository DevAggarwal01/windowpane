defmodule Windowpane.Repo.Migrations.AddRecordingToLiveStreams do
  use Ecto.Migration

  def change do
    alter table(:live_streams) do
      add :recording, :boolean, default: true, null: false
    end
  end
end
