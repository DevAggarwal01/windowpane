defmodule Windowpane.Repo.Migrations.ModifyTrailerUploadUrlType do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      modify :trailer_upload_url, :text
    end
  end
end
