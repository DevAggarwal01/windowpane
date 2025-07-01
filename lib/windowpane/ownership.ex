defmodule Windowpane.Ownership do
  @moduledoc """
  The Ownership context for managing user ownership of content.
  """

  import Ecto.Query, warn: false
  alias Windowpane.Repo
  alias Windowpane.OwnershipRecord

  @doc """
  Creates an ownership record for a rental.
  If an ownership record already exists but is expired, it will be updated with new JWT token and expiration.
  """
  def create_rental(user_id, project_id, jwt_token \\ nil, expires_at \\ nil) do
    case get_ownership_record(user_id, project_id) do
      nil ->
        # No existing record, create a new one
        create_new_rental(user_id, project_id, jwt_token, expires_at)

      existing_record ->
        # Record exists, check if it's expired
        if OwnershipRecord.valid?(existing_record) do
          # Record is still active
          {:error, :already_owns}
        else
          # Record is expired, update it
          update_expired_rental(existing_record, jwt_token, expires_at)
        end
    end
  end

  @doc """
  Creates a new ownership record.
  """
  defp create_new_rental(user_id, project_id, jwt_token, expires_at) do
    %OwnershipRecord{}
    |> OwnershipRecord.new_rental_changeset(%{
      user_id: user_id,
      project_id: project_id,
      jwt_token: jwt_token,
      expires_at: expires_at
    })
    |> Repo.insert()
  end

  @doc """
  Updates an expired ownership record with a new JWT token and expiration.
  """
  defp update_expired_rental(ownership_record, jwt_token, expires_at) do
    ownership_record
    |> OwnershipRecord.renewal_changeset(%{
      jwt_token: jwt_token,
      expires_at: expires_at
    })
    |> Repo.update()
  end

  @doc """
  Gets a single ownership record by user_id and project_id.
  """
  def get_ownership_record(user_id, project_id) do
    Repo.get_by(OwnershipRecord, user_id: user_id, project_id: project_id)
  end

  @doc """
  Gets an active ownership record by user_id and project_id.
  Returns nil if no record exists or if the record is expired.
  """
  def get_active_ownership_record(user_id, project_id) do
    case get_ownership_record(user_id, project_id) do
      nil -> nil
      record -> if OwnershipRecord.valid?(record), do: record, else: nil
    end
  end

  @doc """
  Checks if a user owns (has active access to) a project.
  """
  def user_owns_project?(user_id, project_id) do
    case get_ownership_record(user_id, project_id) do
      nil -> false
      record -> OwnershipRecord.valid?(record)
    end
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
