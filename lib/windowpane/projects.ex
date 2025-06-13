defmodule Windowpane.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  alias Windowpane.Repo
  alias Windowpane.Projects.Project
  alias Windowpane.Projects.Film
  alias Windowpane.Projects.ProjectApprovalQueue

  @doc """
  Returns the list of projects for a creator.

  ## Examples

      iex> list_projects(creator_id)
      [%Project{}, ...]

  """
  def list_projects(creator_id) do
    Project
    |> where([p], p.creator_id == ^creator_id)
    |> Repo.all()
  end

  @doc """
  Returns the list of projects for a creator filtered by type.

  ## Examples

      iex> list_projects_by_type(creator_id, "film")
      [%Project{}, ...]

  """
  def list_projects_by_type(creator_id, type) do
    Project
    |> where([p], p.creator_id == ^creator_id and p.type == ^type)
    |> Repo.all()
  end

  @doc """
  Gets a single project.

  Raises `Ecto.NoResultsError` if the Project does not exist.

  ## Examples

      iex> get_project!(123)
      %Project{}

      iex> get_project!(456)
      ** (Ecto.NoResultsError)

  """
  def get_project!(id), do: Repo.get!(Project, id)

  @doc """
  Gets a single project with film preloaded.

  Raises `Ecto.NoResultsError` if the Project does not exist.

  ## Examples

      iex> get_project_with_film!(123)
      %Project{}

  """
  def get_project_with_film!(id) do
    Project
    |> Repo.get!(id)
    |> Repo.preload(:film)
  end

  @doc """
  Gets a project by specific field criteria.

  Returns nil if no project is found.

  ## Examples

      iex> get_project_by!(trailer_asset_id: "asset_123")
      %Project{}

      iex> get_project_by!(film_asset_id: "asset_456")
      %Project{}

  """
  def get_project_by!(clauses) do
    # Handle film-specific fields by joining with films table
    case clauses do
      [trailer_asset_id: asset_id] ->
        from(p in Project,
          join: f in Film,
          on: p.id == f.project_id,
          where: f.trailer_asset_id == ^asset_id,
          preload: [:film]
        )
        |> Repo.one()

      [film_asset_id: asset_id] ->
        from(p in Project,
          join: f in Film,
          on: p.id == f.project_id,
          where: f.film_asset_id == ^asset_id,
          preload: [:film]
        )
        |> Repo.one()

      _ ->
        # For other fields, query the project table directly
        Repo.get_by(Project, clauses)
    end
  end

  @doc """
  Creates a project.

  ## Examples

      iex> create_project(%{field: value})
      {:ok, %Project{}}

      iex> create_project(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_project(attrs \\ %{}) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a project.

  ## Examples

      iex> update_project(project, %{field: new_value})
      {:ok, %Project{}}

      iex> update_project(project, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a project.

  ## Examples

      iex> delete_project(project)
      {:ok, %Project{}}

      iex> delete_project(project)
      {:error, %Ecto.Changeset{}}

  """
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project changes.

  ## Examples

      iex> change_project(project)
      %Ecto.Changeset{data: %Project{}}

  """
  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end

  # Film-related functions

  @doc """
  Creates a film for a project.

  ## Examples

      iex> create_film(%{project_id: 1})
      {:ok, %Film{}}

      iex> create_film(%{project_id: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_film(attrs \\ %{}) do
    %Film{}
    |> Film.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a film.

  ## Examples

      iex> update_film(film, %{field: new_value})
      {:ok, %Film{}}

      iex> update_film(film, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_film(%Film{} = film, attrs) do
    film
    |> Film.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets or creates a film for a project.

  ## Examples

      iex> get_or_create_film(project)
      %Film{}

  """
  def get_or_create_film(%Project{} = project) do
    case Repo.preload(project, :film).film do
      nil ->
        {:ok, film} = create_film(%{project_id: project.id})
        film
      film ->
        film
    end
  end

  @doc """
  Adds a project to the approval queue.
  Returns {:ok, queue_entry} if successful, {:error, changeset} if there's an error.
  """
  def add_to_approval_queue(project) do
    %ProjectApprovalQueue{}
    |> ProjectApprovalQueue.changeset(%{project_id: project.id})
    |> Repo.insert()
  end

  @doc """
  Checks if a project is already in the approval queue.
  Returns true if the project is in the queue, false otherwise.
  """
  def in_approval_queue?(project) do
    Repo.exists?(from q in ProjectApprovalQueue, where: q.project_id == ^project.id)
  end

  @doc """
  Returns a list of project IDs that are waiting for approval.

  ## Parameters
    - limit: The maximum number of project IDs to return

  ## Examples

      iex> list_pending_approvals(5)
      [1, 2, 3]

  """
  def list_pending_approvals(limit) when is_integer(limit) and limit > 0 do
    ProjectApprovalQueue
    |> order_by([q], [asc: q.inserted_at])
    |> limit(^limit)
    |> select([q], q.project_id)
    |> Repo.all()
  end

  @doc """
  Validates if a project is ready for deployment.

  Checks that all required fields are filled and all uploads (film, trailer, cover) exist.

  ## Examples

      iex> ready_for_deployment?(project)
      true

      iex> ready_for_deployment?(incomplete_project)
      false
  """
  def ready_for_deployment?(project) do
    # Check required fields are not nil or empty
    required_fields_valid = [
      field_valid?(project.title),
      field_valid?(project.description),
      field_valid?(project.type),
      field_valid?(project.premiere_date),
      field_valid?(project.premiere_price),
      field_valid?(project.rental_price),
      field_valid?(project.rental_window_hours),
      field_valid?(project.purchase_price)
    ]

    # Check uploads exist
    uploads_valid = [
      film_uploaded?(project),
      trailer_uploaded?(project),
      cover_uploaded?(project)
    ]

    # All validations must pass
    Enum.all?(required_fields_valid ++ uploads_valid)
  end

  # Helper function to check if a field is valid (not nil or empty)
  defp field_valid?(nil), do: false
  defp field_valid?(""), do: false
  defp field_valid?(_), do: true

  # Helper function to check if film is uploaded
  defp film_uploaded?(project) do
    case project.film do
      nil -> false
      film -> field_valid?(film.film_upload_id)
    end
  end

  # Helper function to check if trailer is uploaded
  defp trailer_uploaded?(project) do
    case project.film do
      nil -> false
      film -> field_valid?(film.trailer_upload_id)
    end
  end

  # Helper function to check if cover is uploaded
  defp cover_uploaded?(project) do
    Windowpane.Uploaders.CoverUploader.cover_exists?(project)
  end

  @doc """
  Removes a project from the approval queue.
  Returns {:ok, _} if successful, {:error, _} if there's an error.
  """
  def remove_from_approval_queue(project) do
    from(q in ProjectApprovalQueue, where: q.project_id == ^project.id)
    |> Repo.delete_all()
  end
end
