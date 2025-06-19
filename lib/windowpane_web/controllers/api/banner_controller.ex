defmodule WindowpaneWeb.Api.BannerController do
  use WindowpaneWeb, :controller

  alias Windowpane.Projects
  alias Windowpane.Uploaders.BannerUploader

  def create(conn, %{"id" => project_id, "banner" => banner_upload}) do
    project = Projects.get_project!(project_id)

    # Validate the upload
    if File.exists?(banner_upload.path) do
      # Read the uploaded file binary data
      case File.read(banner_upload.path) do
        {:ok, file_binary} ->
          # Get bucket and construct object key
          bucket = System.get_env("TIGRIS_BUCKET")
          object_key = "#{project.id}/banner"

          # Get content type from the uploaded file
          content_type = MIME.from_path(banner_upload.filename) || "application/octet-stream"

          IO.puts("=== DIRECT S3 BANNER UPLOAD DEBUG (TIGRIS) ===")
          IO.puts("Bucket: #{bucket}")
          IO.puts("Object Key: #{object_key}")
          IO.puts("Content Type: #{content_type}")
          IO.puts("File Size: #{byte_size(file_binary)} bytes")

          # Upload directly to Tigris using ExAws
          case ExAws.S3.put_object(bucket, object_key, file_binary, [
            content_type: content_type,
            acl: :public_read
          ]) |> ExAws.request() do
            {:ok, _response} ->
              IO.puts("✅ Banner upload successful!")
              json(conn, %{
                success: true,
                message: "Banner uploaded successfully",
                url: BannerUploader.banner_url(project)
              })

            {:error, reason} ->
              IO.puts("❌ Banner upload failed: #{inspect(reason)}")
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{success: false, error: "Upload failed: #{inspect(reason)}"})
          end

        {:error, file_error} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: "Could not read upload file: #{inspect(file_error)}"})
      end
    else
      conn
      |> put_status(:bad_request)
      |> json(%{success: false, error: "Upload file not found"})
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
