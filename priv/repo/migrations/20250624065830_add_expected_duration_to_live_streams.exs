defmodule Windowpane.Repo.Migrations.AddExpectedDurationToLiveStreams do
  use Ecto.Migration

  def change do
    alter table(:live_streams) do
      add :expected_duration_minutes, :integer
    end
  end
end
