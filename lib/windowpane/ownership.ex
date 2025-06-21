defmodule Windowpane.Ownership do
  @moduledoc """
  The Ownership context for managing user ownership of content.
  """

  import Ecto.Query, warn: false
  alias Windowpane.Repo
  alias Windowpane.OwnershipRecord

  @doc """
  Creates an ownership record for a rental.
  """
  def create_rental(user_id, project_id, jwt_token \\ nil) do
    attrs = %{
      user_id: user_id,
      project_id: project_id,
      jwt_token: jwt_token
    }

    %OwnershipRecord{}
    |> OwnershipRecord.new_rental_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets all active ownership records for a user.
  """
  def get_user_active_rentals(user_id) do
    now = DateTime.utc_now()

    from(ownership in OwnershipRecord,
      where: ownership.user_id == ^user_id and ownership.expires_at > ^now,
      preload: [:project]
    )
    |> Repo.all()
  end

  @doc """
  Checks if a user owns or has rented a specific project.
  """
  def user_owns_project?(user_id, project_id) do
    now = DateTime.utc_now()

    from(ownership in OwnershipRecord,
      where: ownership.user_id == ^user_id and ownership.project_id == ^project_id and ownership.expires_at > ^now
    )
    |> Repo.exists?()
  end

  @doc """
  Gets a specific ownership record.
  """
  def get_ownership_record(user_id, project_id) do
    from(ownership in OwnershipRecord,
      where: ownership.user_id == ^user_id and ownership.project_id == ^project_id,
      preload: [:user, :project]
    )
    |> Repo.one()
  end

  @doc """
  Gets the active ownership record for a user and project.
  Returns nil if the user doesn't have an active (non-expired) ownership.
  """
  def get_active_ownership_record(user_id, project_id) do
    now = DateTime.utc_now()

    from(ownership in OwnershipRecord,
      where: ownership.user_id == ^user_id and ownership.project_id == ^project_id and ownership.expires_at > ^now,
      order_by: [desc: ownership.expires_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Gets all ownership records that have expired.
  This is useful for cleanup or analytics.
  """
  def get_expired_records do
    now = DateTime.utc_now()

    from(ownership in OwnershipRecord,
      where: ownership.expires_at < ^now
    )
    |> Repo.all()
  end
end
