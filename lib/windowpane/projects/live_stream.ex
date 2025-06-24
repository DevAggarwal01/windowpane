defmodule Windowpane.Projects.LiveStream do
  use Ecto.Schema
  import Ecto.Changeset

  schema "live_streams" do
    field :mux_stream_id, :string           # Mux's unique identifier for the live stream
    field :stream_key, :string              # Mux stream key
    field :playback_id, :string             # Used to embed/serve the live stream
    field :expected_duration_minutes, :integer # Expected duration of the live stream in minutes
    field :recording, :boolean, default: true # Whether recording is enabled for this stream
    # Note: The asset ID of the recording will be stored in film entry which is connected through project
    field :status, :string, default: "idle" # idle | active | ended | errored

    # Relations
    belongs_to :project, Windowpane.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(live_stream, attrs) do
    live_stream
    |> cast(attrs, [
      :mux_stream_id,
      :stream_key,
      :playback_id,
      :expected_duration_minutes,
      :recording,
      :status,
      :project_id
    ])
    |> validate_required([:status, :project_id, :expected_duration_minutes, :recording])
    |> validate_inclusion(:status, ["idle", "active", "ended", "errored"])
    |> validate_number(:expected_duration_minutes, greater_than: 0, message: "must be greater than 0")
    |> foreign_key_constraint(:project_id)
    |> unique_constraint(:mux_stream_id)
    |> unique_constraint(:stream_key)
    |> unique_constraint(:playback_id)
  end

  @doc """
  Changeset for updating with Mux integration data.
  Use this when adding Mux stream details to an existing live stream.
  """
  def mux_changeset(live_stream, attrs) do
    live_stream
    |> cast(attrs, [
      :mux_stream_id,
      :stream_key,
      :playback_id,
      :expected_duration_minutes,
      :recording,
      :status
    ])
    |> validate_required([:mux_stream_id, :stream_key, :playback_id])
    |> validate_inclusion(:status, ["idle", "active", "ended", "errored"])
    |> validate_number(:expected_duration_minutes, greater_than: 0, message: "must be greater than 0")
    |> unique_constraint(:mux_stream_id)
    |> unique_constraint(:stream_key)
    |> unique_constraint(:playback_id)
  end
end
