defmodule Windowpane.Uploaders.CoverUploader do
  use Waffle.Definition

  # To add a thumbnail version:
  # @versions [:original, :thumb]

  @versions [:original]

  # Set ACL to public_read for all uploads (required for Backblaze B2)
  @acl :public_read

  # Whitelist file extensions:
  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    case Enum.member?(~w(.jpg .jpeg .png .webp), file_extension) do
      true -> :ok
      false -> {:error, "invalid file type"}
    end
  end

  # Define a thumbnail transformation:
  # def transform(:thumb, _) do
  #   {:convert, "-strip -thumbnail 300x300^ -gravity center -extent 300x300 -format png", :png}
  # end

  # Override the storage directory:
  def storage_dir(_version, {_file, scope}) do
    "#{scope.id}"
  end

  # Override the filename:
  def filename(_version, {_file, _scope}) do
    "cover"
  end

  # Override the storage location (optional if using S3):
  def __storage, do: Waffle.Storage.S3

  # Specify custom headers for S3:
  def s3_object_headers(_version, {file, _scope}) do
    content_type = MIME.from_path(file.file_name)
    [
      content_type: content_type,
      acl: :public_read
    ]
  end

  # Helper Functions

  @doc """
  Generates the public URL for a project's cover image.
  """
  def cover_url(project, version \\ :original) do
    bucket = System.get_env("TIGRIS_BUCKET")
    object_key = "#{project.id}/cover"

    "https://#{bucket}.t3.storage.dev/#{object_key}"
  end

  @doc """
  Checks if a cover image exists for the given project using ExAws.
  """
  def cover_exists?(project_id) when is_integer(project_id) or is_binary(project_id) do
    bucket = System.get_env("TIGRIS_BUCKET")
    object_key = "#{project_id}/cover"
    # Generate the URL that would be accessed
    url = "https://#{bucket}.t3.storage.dev/#{object_key}"

    IO.puts("=== COVER EXISTS DEBUG (TIGRIS) ===")
    IO.puts("Project ID: #{project_id}")
    IO.puts("Bucket: #{bucket}")
    IO.puts("Object Key: #{object_key}")
    IO.puts("Generated URL: #{url}")

    case ExAws.S3.head_object(bucket, object_key) |> ExAws.request() do
      {:ok, _response} ->
        IO.puts("✅ Cover exists!")
        true
      {:error, {:http_error, 404, _body}} ->
        IO.puts("❌ Cover not found (404)")
        false
      {:error, error} ->
        IO.puts("❌ S3 Error: #{inspect(error)}")
        false
    end
  end

  def cover_exists?(project) when is_map(project) do
    cover_exists?(project.id)
  end

  @doc """
  Generates the storage path for a project's cover image.
  """
  def cover_path(project, version \\ :original) do
    storage_dir = "#{project.id}"
    filename = if version == :original, do: "cover", else: "cover_#{version}"
    "#{storage_dir}/#{filename}"
  end

  @doc """
  Deletes the cover image for a project.
  """
  def delete_cover(project) do
    fake_file = %{file_name: "cover"}
    delete({fake_file, project})
  end

  @doc """
  Debug function to test Tigris connection and configuration.
  """
  def debug_s3_connection do
    IO.puts("=== TIGRIS CONNECTION DEBUG ===")

    # Check environment variables
    bucket = System.get_env("TIGRIS_BUCKET")
    access_key = System.get_env("TIGRIS_ACCESS_KEY_ID")
    secret_key = System.get_env("TIGRIS_SECRET_KEY")

    IO.puts("TIGRIS_BUCKET: #{inspect(bucket)}")
    IO.puts("TIGRIS_ACCESS_KEY_ID: #{if access_key, do: "✅ Set (#{String.length(access_key)} chars)", else: "❌ Not set"}")
    IO.puts("TIGRIS_SECRET_KEY: #{if secret_key, do: "✅ Set (#{String.length(secret_key)} chars)", else: "❌ Not set"}")

    # Check ExAws config
    config = ExAws.Config.new(:s3)
    IO.puts("ExAws S3 Config: #{inspect(config)}")

    # Test basic Tigris connection by listing bucket
    if bucket do
      IO.puts("Testing Tigris connection by listing bucket contents...")
      case ExAws.S3.list_objects_v2(bucket, max_keys: 1) |> ExAws.request() do
        {:ok, response} ->
          IO.puts("✅ Tigris connection successful!")
          IO.puts("Bucket contents sample: #{inspect(response)}")
        {:error, error} ->
          IO.puts("❌ Tigris connection failed: #{inspect(error)}")
      end
    else
      IO.puts("❌ Cannot test Tigris - TIGRIS_BUCKET not set")
    end
  end

  @doc """
  Debug function to check what files exist for a project.
  """
  def debug_project_files(project_id) do
    bucket = System.get_env("TIGRIS_BUCKET")
    prefix = "#{project_id}/"

    IO.puts("=== PROJECT FILES DEBUG (TIGRIS) ===")
    IO.puts("Project ID: #{project_id}")
    IO.puts("Bucket: #{bucket}")
    IO.puts("Prefix: #{prefix}")

    case ExAws.S3.list_objects_v2(bucket, prefix: prefix) |> ExAws.request() do
      {:ok, %{body: %{contents: contents}}} ->
        IO.puts("Files found:")
        Enum.each(contents, fn object ->
          IO.puts("  - #{object.key} (#{object.size} bytes, #{object.last_modified})")
        end)
      {:error, error} ->
        IO.puts("❌ Error listing files: #{inspect(error)}")
    end
  end
end
