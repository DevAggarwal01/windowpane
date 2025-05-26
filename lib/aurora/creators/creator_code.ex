defmodule Aurora.Creators.CreatorCode do
  use Ecto.Schema
  import Ecto.Changeset

  schema "creator_codes" do
    field :code, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(creator_code, attrs) do
    creator_code
    |> cast(attrs, [:code])
    |> validate_required([:code])
    |> unique_constraint(:code)
  end
end
