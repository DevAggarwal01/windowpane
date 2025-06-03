defmodule Aurora.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  alias Aurora.Repo
  alias Aurora.Projects.Project
  alias Aurora.Projects.ProjectApprovalQueue

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
end
