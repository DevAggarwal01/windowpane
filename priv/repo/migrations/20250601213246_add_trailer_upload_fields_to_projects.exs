defmodule Windowpane.Repo.Migrations.AddTrailerUploadFieldsToProjects do
  use Ecto.Migration

  def change do
    # Check if columns exist before trying to add them
    unless column_exists?(:projects, :trailer_upload_url) do
      alter table(:projects) do
        add :trailer_upload_url, :string
      end
    end

    unless column_exists?(:projects, :trailer_upload_id) do
      alter table(:projects) do
        add :trailer_upload_id, :string
      end
    end
  end

  defp column_exists?(table, column) do
    query = """
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name = '#{table}'
    AND column_name = '#{column}'
    """

    case Ecto.Adapters.SQL.query(Windowpane.Repo, query, []) do
      {:ok, %{rows: [[_]]}} -> true
      _ -> false
    end
  end
end
