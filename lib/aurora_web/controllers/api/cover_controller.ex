defmodule AuroraWeb.Api.CoverController do
  use AuroraWeb, :controller

  alias Aurora.Projects
  alias Aurora.Uploaders.CoverUploader

  def create(conn, %{"id" => project_id, "cover" => cover_upload}) do
    project = Projects.get_project!(project_id)

    # Pass the actual Plug.Upload struct to Waffle
    case CoverUploader.store({cover_upload, project}) do
      {:ok, _filename} ->
        json(conn, %{success: true, message: "Cover uploaded successfully"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, error: inspect(reason)})
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{success: false, error: "Project not found"})

    error ->
      conn
      |> put_status(:internal_server_error)
      |> json(%{success: false, error: "Upload failed: #{inspect(error)}"})
  end
end
