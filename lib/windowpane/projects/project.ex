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
    field :purchase_price, :decimal
    field :status, :string, default: "draft"
    field :creator_id, :id

    # Relations
    belongs_to :creator, Windowpane.Accounts.Creator, define_field: false
    has_one :film, Windowpane.Projects.Film
    has_many :reviews, Windowpane.Projects.ProjectReview

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
      :purchase_price,
      :status,
      :creator_id
    ])
    |> validate_required([
      :title,
      :description,
      :type,
      :premiere_date,
      :rental_price,
      :rental_window_hours,
      :purchase_price,
      :creator_id
    ])
    |> validate_inclusion(:type, @project_types)
    |> validate_number(:premiere_price, greater_than_or_equal_to: 0)
    |> validate_number(:rental_price, greater_than_or_equal_to: 0)
    |> validate_number(:purchase_price, greater_than_or_equal_to: 0)
    |> validate_number(:rental_window_hours, greater_than: 0)
    |> validate_inclusion(:status, ["draft", "published", "archived", "waiting for approval"])
    |> foreign_key_constraint(:creator_id)
  end
end
