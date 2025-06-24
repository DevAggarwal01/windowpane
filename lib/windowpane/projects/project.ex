defmodule Windowpane.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  alias Windowpane.PricingCalculator

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
    field :premiere_creator_cut, :decimal
    field :rental_creator_cut, :decimal
    field :creator_id, :id

    # Relations
    belongs_to :creator, Windowpane.Creators.Creator, define_field: false
    has_one :film, Windowpane.Projects.Film
    has_one :live_stream, Windowpane.Projects.LiveStream
    has_many :reviews, Windowpane.Projects.ProjectReview
    has_many :ownership_records, Windowpane.OwnershipRecord

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
      :premiere_creator_cut,
      :rental_creator_cut,
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
    |> validate_number(:premiere_creator_cut, greater_than_or_equal_to: 0)
    |> validate_number(:rental_creator_cut, greater_than_or_equal_to: 0)
    |> validate_number(:rental_window_hours, greater_than: 0)
    |> validate_inclusion(:status, ["draft", "published", "archived", "waiting for approval"])
    |> foreign_key_constraint(:creator_id)
    |> cast_assoc(:live_stream)
    |> calculate_creator_cuts_if_needed()
  end

  # Calculate initial creator cuts when premiere_price or rental_price are provided
  defp calculate_creator_cuts_if_needed(changeset) do
    changeset
    |> calculate_premiere_creator_cut_if_needed()
    |> calculate_rental_creator_cut_if_needed()
  end

  defp calculate_premiere_creator_cut_if_needed(changeset) do
    case get_change(changeset, :premiere_price) do
      nil -> changeset
      premiere_price ->
        price_float = PricingCalculator.normalize_price(premiere_price)
        creator_cut = PricingCalculator.calculate_creator_cut(price_float)
        put_change(changeset, :premiere_creator_cut, creator_cut)
    end
  end

  defp calculate_rental_creator_cut_if_needed(changeset) do
    case get_change(changeset, :rental_price) do
      nil -> changeset
      rental_price ->
        price_float = PricingCalculator.normalize_price(rental_price)
        creator_cut = PricingCalculator.calculate_creator_cut(price_float)
        put_change(changeset, :rental_creator_cut, creator_cut)
    end
  end
end
