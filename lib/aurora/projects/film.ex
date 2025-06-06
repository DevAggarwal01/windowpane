defmodule Aurora.Projects.Film do
  use Ecto.Schema
  import Ecto.Changeset

  schema "films" do
    field :trailer_upload_id, :string
    field :trailer_asset_id, :string
    field :trailer_playback_id, :string
    field :film_upload_id, :string
    field :film_asset_id, :string
    field :film_playback_id, :string

    # Relations
    belongs_to :project, Aurora.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(film, attrs) do
    film
    |> cast(attrs, [:trailer_upload_id, :trailer_asset_id, :trailer_playback_id, :film_upload_id, :film_asset_id, :film_playback_id, :project_id])
    |> unique_constraint(:project_id)
  end
end
