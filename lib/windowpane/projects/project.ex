defmodule Windowpane.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @project_types ["film", "tv_show", "live_event", "book", "music"]

  schema "projects" do
    field :title, :string
    field :description, :string
    field :type, :string
    field :premiere_date, :utc_datetime
    field :premiere_price, :decimal
    field :rental_price, :decimal
    field :rental_window_hours, :integer
    field :status, :string, default: "draft"
    field :periodic_views, :integer, default: 0
    field :creator_id, :id

    # Relations
    belongs_to :creator, Windowpane.Creators.Creator, define_field: false
    has_one :film, Windowpane.Projects.Film
    has_one :live_stream, Windowpane.Projects.LiveStream
    has_many :reviews, Windowpane.Projects.ProjectReview
    has_many :ownership_records, Windowpane.OwnershipRecord
    has_one :premiere, Windowpane.Projects.Premiere

    timestamps()
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :title,
      :description,
      :type,
      :premiere_date,
      :premiere_price,
      :rental_price,
      :rental_window_hours,
      :status,
      :periodic_views,
      :creator_id
    ])
    |> validate_required([
      :title,
      :description,
      :type,
      :premiere_date,
      :rental_price,
      :rental_window_hours,
      :creator_id
    ])
    |> validate_inclusion(:type, @project_types)
    |> validate_number(:premiere_price, greater_than_or_equal_to: 0)
    |> validate_number(:rental_price, greater_than_or_equal_to: 0)
    |> validate_number(:periodic_views, greater_than_or_equal_to: 0)
    |> validate_number(:rental_window_hours, greater_than: 0)
    |> validate_inclusion(:status, ["draft", "published", "archived", "waiting for approval"])
    |> foreign_key_constraint(:creator_id)
    |> cast_assoc(:live_stream)
  end
end
