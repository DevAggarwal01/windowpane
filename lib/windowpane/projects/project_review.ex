defmodule Windowpane.Projects.ProjectReview do
  use Ecto.Schema
  import Ecto.Changeset

  schema "project_reviews" do
    field :status, :string
    field :feedback, :string

    belongs_to :project, Windowpane.Projects.Project

    timestamps()
  end

  @doc false
  def changeset(project_review, attrs) do
    project_review
    |> cast(attrs, [:status, :feedback, :project_id])
    |> validate_required([:status, :project_id])
    |> validate_inclusion(:status, ["approved", "denied"])
  end
end
