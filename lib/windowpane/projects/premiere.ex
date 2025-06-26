defmodule Windowpane.Projects.Premiere do
  use Ecto.Schema
  import Ecto.Changeset

  schema "premieres" do
    field :start_time, :utc_datetime # this is an index so we can use start time and end time to query for valid premieres in comparison with now()
    field :end_time, :utc_datetime # this is an index so we can use start time and end time to query for valid premieres in comparison with now()

    # Relations
    belongs_to :project, Windowpane.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(premiere, attrs) do
    premiere
    |> cast(attrs, [:start_time, :end_time, :project_id])
    |> validate_required([:start_time, :end_time, :project_id])
    |> validate_end_time_after_start_time()
    |> foreign_key_constraint(:project_id)
    |> unique_constraint(:project_id)
  end

  defp validate_end_time_after_start_time(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    case {start_time, end_time} do
      {%DateTime{} = start_time, %DateTime{} = end_time} ->
        if DateTime.compare(end_time, start_time) == :gt do
          changeset
        else
          add_error(changeset, :end_time, "must be after start time")
        end

      _ ->
        changeset
    end
  end
end
