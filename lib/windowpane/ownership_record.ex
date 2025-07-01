defmodule Windowpane.OwnershipRecord do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ownership_records" do
    field :jwt_token, :string
    field :expires_at, :utc_datetime

    belongs_to :user, Windowpane.Accounts.User
    belongs_to :project, Windowpane.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ownership_record, attrs) do
    ownership_record
    |> cast(attrs, [:user_id, :project_id, :jwt_token, :expires_at])
    |> validate_required([:user_id, :project_id, :expires_at])
    |> unique_constraint([:user_id, :project_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:project_id)
  end

  @doc """
  Creates a new ownership record with expiration set to 48 hours from now,
  or uses the provided expiration time.
  """
  def new_rental_changeset(ownership_record, attrs) do
    expires_at = Map.get(attrs, :expires_at) ||
                 (DateTime.utc_now() |> DateTime.add(48, :hour) |> DateTime.truncate(:second))

    ownership_record
    |> changeset(Map.put(attrs, :expires_at, expires_at))
  end

  @doc """
  Updates an existing ownership record for a rental renewal.
  Sets expiration to 48 hours from now or uses the provided expiration time,
  and updates the JWT token.
  """
  def renewal_changeset(ownership_record, attrs) do
    expires_at = Map.get(attrs, :expires_at) ||
                 (DateTime.utc_now() |> DateTime.add(48, :hour) |> DateTime.truncate(:second))

    ownership_record
    |> cast(attrs, [:jwt_token])
    |> put_change(:expires_at, expires_at)
    |> validate_required([:jwt_token, :expires_at])
  end

  @doc """
  Checks if an ownership record is still valid (not expired).
  """
  def valid?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :lt
  end

  def valid?(_), do: false
end
