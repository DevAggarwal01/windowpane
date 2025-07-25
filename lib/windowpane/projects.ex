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
  alias Windowpane.Projects.Premiere

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
    # Load basic project info
    project = Project |> Repo.get!(id)

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
  Updates a live stream with Mux integration data.

  ## Examples

      iex> update_live_stream_with_mux(live_stream, %{mux_stream_id: "stream_123"})
      {:ok, %LiveStream{}}

      iex> update_live_stream_with_mux(live_stream, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_live_stream_with_mux(%LiveStream{} = live_stream, attrs) do
    live_stream
    |> LiveStream.mux_changeset(attrs)
    |> Repo.update()
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

  # Premiere functions

  @doc """
  Creates a premiere for a project.
  Uses the project's premiere_date as start_time and calculates end_time based on duration.
  Only creates premieres for film and live_event project types.

  For films: uses the film's duration field (defaults to 120 minutes if not set)
  For live_events: uses the live_stream's expected_duration_minutes field (defaults to 60 minutes if not set)

  ## Examples

      iex> create_premiere(film_project)
      {:ok, %Premiere{}}

      iex> create_premiere(live_event_project)
      {:ok, %Premiere{}}

      iex> create_premiere(other_project_type)
      {:error, "Premieres can only be created for film and live_event projects, got: book"}

  """
  def create_premiere(%Project{type: type} = project) when type in ["film", "live_event"] do
    # Get duration in minutes based on project type
    duration_minutes = get_project_duration_minutes(project)

    # Calculate end_time = start_time + duration
    start_time = project.premiere_date
    end_time = DateTime.add(start_time, duration_minutes * 60, :second)

    attrs = %{
      project_id: project.id,
      start_time: start_time,
      end_time: end_time
    }

    %Premiere{}
    |> Premiere.changeset(attrs)
    |> Repo.insert()
  end

  def create_premiere(%Project{type: type}) do
    {:error, "Premieres can only be created for film and live_event projects, got: #{type}"}
  end

  defp get_project_duration_minutes(%Project{type: "film", film: film}) when not is_nil(film) do
    film.duration || 120  # Default to 2 hours if duration not set
  end

  defp get_project_duration_minutes(%Project{type: "live_event", live_stream: live_stream}) when not is_nil(live_stream) do
    live_stream.expected_duration_minutes || 60  # Default to 1 hour if not set
  end

  defp get_project_duration_minutes(_project) do
    120  # Default to 2 hours for other project types
  end

  @doc """
  Validates if a live stream project is ready for deployment.

  Checks that all required fields are filled and uploads (cover, banner) exist.
  Also validates that premiere/rental prices are at least $1 and premiere date is in the future.

  ## Examples

      iex> ready_for_live_stream_deployment?(live_stream_project)
      true

      iex> ready_for_live_stream_deployment?(incomplete_project)
      false
  """
  def ready_for_live_stream_deployment?(project) do
    # Check required fields are not nil or empty
    required_fields_valid = [
      field_valid?(project.title),
      field_valid?(project.description),
      field_valid?(project.type),
      field_valid?(project.premiere_date),
      premiere_price_valid?(project.premiere_price),
      premiere_date_in_future?(project.premiere_date)
    ]

    # Check uploads exist (only cover and banner for live streams)
    uploads_valid = [
      cover_uploaded?(project),
      banner_uploaded?(project)
    ]

    # Check recording-specific validations
    recording_validations = if project.live_stream && project.live_stream.recording do
      [rental_price_valid?(project.rental_price)]
    else
      [true] # Recording disabled, so rental price validation passes
    end

    # All validations must pass
    Enum.all?(required_fields_valid ++ uploads_valid ++ recording_validations)
  end

  # Helper function to check if premiere date is in the future
  defp premiere_date_in_future?(nil), do: false
  defp premiere_date_in_future?(premiere_date) do
    DateTime.compare(premiere_date, DateTime.utc_now()) == :gt
  end

  # Helper function to check if premiere price is at least $1
  defp premiere_price_valid?(nil), do: false
  defp premiere_price_valid?(price) when is_number(price), do: price >= 1.0
  defp premiere_price_valid?(price) when is_struct(price, Decimal) do
    Decimal.compare(price, Decimal.new("1.0")) != :lt
  end
  defp premiere_price_valid?(_), do: false

  # Helper function to check if rental price is at least $1 (only when recording is enabled)
  defp rental_price_valid?(nil), do: false
  defp rental_price_valid?(price) when is_number(price), do: price >= 1.0
  defp rental_price_valid?(price) when is_struct(price, Decimal) do
    Decimal.compare(price, Decimal.new("1.0")) != :lt
  end
  defp rental_price_valid?(_), do: false

  @doc """
  Returns a list of upcoming premieres ordered by start time.
  Includes the associated project and creator name for display.
  Only returns premieres that haven't started yet.
  Limits to 6 results by default.

  ## Examples

      iex> list_upcoming_premieres()
      [%Premiere{project: %Project{}, ...}, ...]

  """
  def list_upcoming_premieres(limit \\ 6) do
    now = DateTime.utc_now()

    Premiere
    |> where([p], p.start_time > ^now)
    |> order_by([p], asc: p.start_time)
    |> limit(^limit)
    |> preload(:project)
    |> Repo.all()
    |> Enum.map(fn premiere ->
      # Get creator name separately for security
      creator_name = from(c in Windowpane.Creators.Creator,
        where: c.id == ^premiere.project.creator_id,
        select: c.name
      ) |> Repo.one()

      # Add creator name to project
      project = Map.put(premiere.project, :creator, %{name: creator_name})
      %{premiere | project: project}
    end)
  end

  @doc """
  Returns a list of minimal project data for landing page rows.
  Only returns id, title, and creator name for performance.

  ## Examples

      iex> list_minimal_published_films(6)
      [%{id: 1, title: "Film Title", creator_name: "..."}, ...]

  """
  def list_minimal_published_films(limit \\ 6) do
    Project
    |> where([p], p.type == "film" and p.status == "published")
    |> limit(^limit)
    |> join(:inner, [p], c in Windowpane.Creators.Creator, on: p.creator_id == c.id)
    |> select([p, c], %{
      id: p.id,
      title: p.title,
      creator_name: c.name
    })
    |> order_by([p], desc: p.premiere_date)
    |> Repo.all()
  end

  @doc """
  Returns a list of minimal premiere data for landing page rows.
  Only returns id, title, creator name, and start_time for performance.

  ## Examples

      iex> list_minimal_upcoming_premieres(6)
      [%{id: 1, title: "Film Title", creator_name: "...", start_time: ~U[2024-03-20 10:00:00Z]}, ...]

  """
  def list_minimal_upcoming_premieres(limit \\ 6) do
    now = DateTime.utc_now()

    Premiere
    |> where([p], p.start_time > ^now)
    |> order_by([p], asc: p.start_time)
    |> limit(^limit)
    |> join(:inner, [p], proj in Project, on: p.project_id == proj.id)
    |> join(:inner, [p, proj], c in Windowpane.Creators.Creator, on: proj.creator_id == c.id)
    |> select([p, proj, c], %{
      id: proj.id,
      title: proj.title,
      creator_name: c.name,
      start_time: p.start_time
    })
    |> Repo.all()
  end

  @doc """
  Returns a list of minimal premiere data for landing page rows.
  Only includes premieres that are currently happening (started but not ended).

  ## Examples

      iex> list_minimal_current_premieres(6)
      [%{id: 123, title: "Film Title", creator_name: "Creator Name", start_time: ~U[2024-03-20 10:00:00Z]}, ...]

  """
  def list_minimal_current_premieres(limit \\ 6) do
    now = DateTime.utc_now()

    # Debug: Log the current time being used
    IO.puts("Checking current premieres at: #{DateTime.to_string(now)}")

    results = Premiere
    |> where([p], p.start_time <= ^now and p.end_time > ^now)
    |> order_by([p], asc: p.start_time)
    |> limit(^limit)
    |> join(:inner, [p], proj in Project, on: p.project_id == proj.id)
    |> join(:inner, [p, proj], c in Windowpane.Creators.Creator, on: proj.creator_id == c.id)
    |> select([p, proj, c], %{
      id: proj.id,
      title: proj.title,
      creator_name: c.name,
      start_time: p.start_time
    })
    |> Repo.all()

    # Debug: Log the results
    IO.puts("Current premieres found: #{inspect(results, pretty: true)}")

    results
  end

  @doc """
  Gets the playback ID for a project based on the specified type.

  ## Examples

      iex> get_playback_id(project, "film")
      "abc123..."

      iex> get_playback_id(project, "trailer")
      "xyz789..."

      iex> get_playback_id(project, "livestream")
      "live456..."

  """
  def get_playback_id(project, type) do
    case type do
      "film" ->
        Repo.one(
          from f in Film,
          where: f.project_id == ^project.id,
          select: f.film_playback_id
        )

      "trailer" ->
        Repo.one(
          from f in Film,
          where: f.project_id == ^project.id,
          select: f.trailer_playback_id
        )

      "livestream" ->
        Repo.one(
          from ls in LiveStream,
          where: ls.project_id == ^project.id,
          select: ls.playback_id
        )

      _ ->
        nil
    end
  end

  @doc """
  Returns a list of random project IDs where status is "published".

  ## Examples

      iex> get_random_published_project_ids(5)
      [1, 3, 7, 12, 15]

      iex> get_random_published_project_ids(10)
      [2, 4, 6, 8, 10, 13, 16, 19, 22, 25]

  """
  def get_random_published_project_ids(limit) when is_integer(limit) and limit > 0 do
    Project
    |> where([p], p.status == "published")
    |> select([p], p.id)
    |> order_by(fragment("RANDOM()"))
    |> limit(^limit)
    |> Repo.all()
  end
end
