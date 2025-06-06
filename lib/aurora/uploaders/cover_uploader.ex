defmodule Aurora.Uploaders.CoverUploader do
  use Waffle.Definition

  # To add a thumbnail version:
  # @versions [:original, :thumb]

  @versions [:original]

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
    "projects/#{scope.id}"
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
    fake_file = %{file_name: "cover"}
    url({fake_file, project}, version)
  end

  @doc """
  Checks if a cover image exists for the given project by making a head request to S3.
  """
  def cover_exists?(project_id) when is_integer(project_id) or is_binary(project_id) do
    bucket = System.fetch_env!("WASABI_BUCKET")
    object_key = "projects/#{project_id}/cover"

    IO.puts("=== COVER EXISTS DEBUG ===")
    IO.puts("Project ID: #{project_id}")
    IO.puts("Bucket: #{bucket}")
    IO.puts("Object Key: #{object_key}")

    result = ExAws.S3.head_object(bucket, object_key) |> ExAws.request()
    IO.puts("S3 Head Object Result: #{inspect(result)}")

    case result do
      {:ok, response} ->
        IO.puts("✅ Cover exists! Response: #{inspect(response)}")
        true
      {:error, {:http_error, 404, body}} ->
        IO.puts("❌ Cover not found (404). Body: #{inspect(body)}")
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
    storage_dir = "projects/#{project.id}"
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
  Debug function to test S3 connection and configuration.
  """
  def debug_s3_connection do
    IO.puts("=== S3 CONNECTION DEBUG ===")

    # Check environment variables
    bucket = System.get_env("WASABI_BUCKET")
    access_key = System.get_env("WASABI_ACCESS_KEY")
    secret_key = System.get_env("WASABI_SECRET_KEY")

    IO.puts("WASABI_BUCKET: #{inspect(bucket)}")
    IO.puts("WASABI_ACCESS_KEY: #{if access_key, do: "✅ Set (#{String.length(access_key)} chars)", else: "❌ Not set"}")
    IO.puts("WASABI_SECRET_KEY: #{if secret_key, do: "✅ Set (#{String.length(secret_key)} chars)", else: "❌ Not set"}")

    # Check ExAws config
    config = ExAws.Config.new(:s3)
    IO.puts("ExAws S3 Config: #{inspect(config)}")

    # Test basic S3 connection by listing bucket
    if bucket do
      IO.puts("Testing S3 connection by listing bucket contents...")
      case ExAws.S3.list_objects_v2(bucket, max_keys: 1) |> ExAws.request() do
        {:ok, response} ->
          IO.puts("✅ S3 connection successful!")
          IO.puts("Bucket contents sample: #{inspect(response)}")
        {:error, error} ->
          IO.puts("❌ S3 connection failed: #{inspect(error)}")
      end
    else
      IO.puts("❌ Cannot test S3 - WASABI_BUCKET not set")
    end
  end
end
