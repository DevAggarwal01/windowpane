defmodule Windowpane.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  alias Windowpane.Repo
  alias Windowpane.Projects.Project
  alias Windowpane.Projects.Film
  alias Windowpane.Projects.ProjectApprovalQueue
  alias Windowpane.Projects.ProjectReview
  alias Windowpane.Projects.LiveStream

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
  Returns a list of queue entries with project information for approval.
  Orders by queue ID (lowest first) for FIFO processing.

  ## Parameters
    - limit: The maximum number of entries to return

  ## Examples

      iex> list_pending_approvals_with_projects(5)
      [%{queue_id: 1, project: %Project{}}, ...]

  """
  def list_pending_approvals_with_projects(limit) when is_integer(limit) and limit > 0 do
    # Get queue entries with lowest IDs
    queue_entries = ProjectApprovalQueue
    |> order_by([q], [asc: q.id])
    |> limit(^limit)
    |> Repo.all()

    # Get project IDs and load projects
    project_ids = Enum.map(queue_entries, & &1.project_id)

    projects = if length(project_ids) > 0 do
      Project
      |> where([p], p.id in ^project_ids)
      |> preload([:film])
      |> Repo.all()
      |> Enum.into(%{}, fn project -> {project.id, project} end)
    else
      %{}
    end

    # Combine queue entries with their projects
    Enum.map(queue_entries, fn queue_entry ->
      %{
        queue_id: queue_entry.id,
        project: Map.get(projects, queue_entry.project_id)
      }
    end)
  end

  @doc """
  Returns a list of project IDs that are waiting for approval.
  Kept for backward compatibility, but consider using list_pending_approvals_with_projects/1

  ## Parameters
    - limit: The maximum number of project IDs to return

  ## Examples

      iex> list_pending_approvals(5)
      [1, 2, 3]

  """
  def list_pending_approvals(limit) when is_integer(limit) and limit > 0 do
    ProjectApprovalQueue
    |> order_by([q], [asc: q.id])
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
      project.rental_window_hours > 0
    ]

    # Check uploads exist
    uploads_valid = [
      film_uploaded?(project),
      trailer_uploaded?(project),
      cover_uploaded?(project),
      banner_uploaded?(project)
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

  # Helper function to check if banner is uploaded
  defp banner_uploaded?(project) do
    Windowpane.Uploaders.BannerUploader.banner_exists?(project)
  end

  @doc """
  Removes a queue entry by its queue ID.
  More efficient than removing by project_id since we have the queue ID from list operations.
  Returns {:ok, _} if successful, {:error, _} if there's an error.
  """
  def remove_queue_entry(queue_id) do
    case Repo.get(ProjectApprovalQueue, queue_id) do
      nil -> {:error, :not_found}
      queue_entry -> Repo.delete(queue_entry)
    end
  end

  @doc """
  Removes a project from the approval queue.
  Returns {:ok, _} if successful, {:error, _} if there's an error.
  """
  def remove_from_approval_queue(project) do
    from(q in ProjectApprovalQueue, where: q.project_id == ^project.id)
    |> Repo.delete_all()
  end

  # Project Review functions

  @doc """
  Creates a project review.

  ## Examples

      iex> create_project_review(%{status: "denied", feedback: "Needs improvement", project_id: 1})
      {:ok, %ProjectReview{}}

      iex> create_project_review(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_project_review(attrs \\ %{}) do
    %ProjectReview{}
    |> ProjectReview.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a project with reviews preloaded.

  ## Examples

      iex> get_project_with_reviews!(123)
      %Project{reviews: [%ProjectReview{}, ...]}

  """
  def get_project_with_reviews!(id) do
    Project
    |> Repo.get!(id)
    |> Repo.preload(:reviews)
    |> Map.update!(:reviews, fn reviews ->
      Enum.sort_by(reviews, & &1.inserted_at, :desc)
    end)
  end

  @doc """
  Gets a project with film and reviews preloaded.

  ## Examples

      iex> get_project_with_film_and_reviews!(123)
      %Project{film: %Film{}, reviews: [%ProjectReview{}, ...]}

  """
  def get_project_with_film_and_reviews!(id) do
    Project
    |> Repo.get!(id)
    |> Repo.preload([:film, :reviews])
    |> Map.update!(:reviews, fn reviews ->
      Enum.sort_by(reviews, & &1.inserted_at, :desc)
    end)
  end

  @doc """
  Gets a project with live stream and reviews preloaded.

  ## Examples

      iex> get_project_with_live_stream_and_reviews!(123)
      %Project{live_stream: %LiveStream{}, reviews: [%ProjectReview{}, ...]}

  """
  def get_project_with_live_stream_and_reviews!(id) do
    Project
    |> Repo.get!(id)
    |> Repo.preload([:live_stream, :reviews])
    |> Map.update!(:reviews, fn reviews ->
      Enum.sort_by(reviews, & &1.inserted_at, :desc)
    end)
  end

  @doc """
  Returns a list of published film projects with films and only creator names (for security).

  ## Examples

      iex> list_published_films_with_creator_names()
      [%Project{}, ...]

      iex> list_published_films_with_creator_names(10)
      [%Project{}, ...]

  """
  def list_published_films_with_creator_names(limit \\ 21) do
    # Get the projects with films
    query = Project
    |> where([p], p.type == "film" and p.status == "published")
    |> preload([:film])
    |> order_by([p], desc: p.premiere_date)

    projects = case limit do
      nil -> Repo.all(query)
      limit when is_integer(limit) ->
        query
        |> limit(^limit)
        |> Repo.all()
    end

    # Get creator names separately for security
    creator_ids = Enum.map(projects, & &1.creator_id)

    creator_names = if length(creator_ids) > 0 do
      from(c in Windowpane.Creators.Creator,
        where: c.id in ^creator_ids,
        select: {c.id, c.name}
      )
      |> Repo.all()
      |> Enum.into(%{})
    else
      %{}
    end

    # Add creator names to projects
    Enum.map(projects, fn project ->
      creator_name = Map.get(creator_names, project.creator_id)
      %{project | creator: %{name: creator_name}}
    end)
  end

  @doc """
  Returns a list of published film projects with films preloaded.
  WARNING: This loads full creator data - use list_published_films_with_creator_names/1 for public display.

  ## Examples

      iex> list_published_films()
      [%Project{}, ...]

      iex> list_published_films(10)
      [%Project{}, ...]

  """
  def list_published_films(limit \\ 21) do
    query = Project
    |> where([p], p.type == "film" and p.status == "published")
    |> preload([:film, :creator])
    |> order_by([p], desc: p.premiere_date)

    case limit do
      nil -> Repo.all(query)
      limit when is_integer(limit) ->
        query
        |> limit(^limit)
        |> Repo.all()
    end
  end

  @doc """
  Returns the count of published film projects.

  ## Examples

      iex> count_published_films()
      5

  """
  def count_published_films do
    Project
    |> where([p], p.type == "film" and p.status == "published")
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets a project with its film and only the creator's name (for security).
  Only loads the minimal creator data needed for display.

  ## Examples

      iex> get_project_with_film_and_creator_name!(123)
      %Project{}

  """
  def get_project_with_film_and_creator_name!(id) do
    # Load project with film
    project = Project
    |> Repo.get!(id)
    |> Repo.preload(:film)

    # Get only the creator's name
    creator_name = from(c in Windowpane.Creators.Creator,
      where: c.id == ^project.creator_id,
      select: c.name
    )
    |> Repo.one!()

    # Manually set the creator with just the name
    %{project | creator: %{name: creator_name}}
  end

  @doc """
  Gets a project with its appropriate associations (film or live_stream) and only the creator's name (for security).
  Only loads the minimal creator data needed for display.

  ## Examples

      iex> get_project_with_associations_and_creator_name!(123)
      %Project{}

  """
  def get_project_with_associations_and_creator_name!(id) do
    # Load project first to determine type
    project = Project |> Repo.get!(id)

    # Preload appropriate associations based on project type
    project = case project.type do
      "film" -> Repo.preload(project, :film)
      "live_event" -> Repo.preload(project, :live_stream)
      _ -> project
    end

    # Get only the creator's name
    creator_name = from(c in Windowpane.Creators.Creator,
      where: c.id == ^project.creator_id,
      select: c.name
    )
    |> Repo.one!()

    # Manually set the creator with just the name
    %{project | creator: %{name: creator_name}}
  end

  # Live Stream functions

  @doc """
  Creates a live stream for a project.

  ## Examples

      iex> create_live_stream(%{project_id: 1, mux_stream_id: "stream_123"})
      {:ok, %LiveStream{}}

      iex> create_live_stream(%{project_id: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_live_stream(attrs \\ %{}) do
    %LiveStream{}
    |> LiveStream.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a live stream.

  ## Examples

      iex> update_live_stream(live_stream, %{status: "active"})
      {:ok, %LiveStream{}}

      iex> update_live_stream(live_stream, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_live_stream(%LiveStream{} = live_stream, attrs) do
    live_stream
    |> LiveStream.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets or creates a live stream for a project.

  ## Examples

      iex> get_or_create_live_stream(project)
      %LiveStream{}

  """
  def get_or_create_live_stream(%Project{} = project) do
    case Repo.get_by(LiveStream, project_id: project.id) do
      nil ->
        {:ok, live_stream} = create_live_stream(%{project_id: project.id})
        live_stream
      live_stream ->
        live_stream
    end
  end
end
