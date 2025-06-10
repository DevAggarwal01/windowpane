defmodule Windowpane.Repo.Migrations.RemoveUploadUrlsFromProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      remove :trailer_upload_url
      remove :film_upload_url
    end
  end
end
