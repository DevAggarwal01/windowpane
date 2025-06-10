defmodule Windowpane.Projects.ProjectApprovalQueue do
  use Ecto.Schema
  import Ecto.Changeset

  schema "project_approval_queue" do
    belongs_to :project, Windowpane.Projects.Project

    timestamps()
  end

  @doc false
  def changeset(project_approval_queue, attrs) do
    project_approval_queue
    |> cast(attrs, [:project_id])
    |> validate_required([:project_id])
    |> unique_constraint(:project_id)
    |> foreign_key_constraint(:project_id)
  end
end
