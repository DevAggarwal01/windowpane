defmodule Windowpane.Projects.Film do
  use Ecto.Schema
  import Ecto.Changeset

  schema "films" do
    field :trailer_upload_id, :string # TODO delete this since i dont think it has any importance
    field :trailer_asset_id, :string
    field :trailer_playback_id, :string
    field :film_upload_id, :string # TODO delete this since i dont think it has any importance
    field :film_asset_id, :string
    field :film_playback_id, :string
    field :duration, :integer # Duration in minutes

    # Relations
    belongs_to :project, Windowpane.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(film, attrs) do
    film
    |> cast(attrs, [:trailer_upload_id, :trailer_asset_id, :trailer_playback_id, :film_upload_id, :film_asset_id, :film_playback_id, :duration, :project_id])
    |> validate_number(:duration, greater_than: 0, message: "must be greater than 0")
    |> unique_constraint(:project_id)
  end
end
