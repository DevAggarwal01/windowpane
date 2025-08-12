defmodule WindowpaneWeb.FilmSetupComponentV2 do
  use WindowpaneWeb, :live_component
  require Logger

  alias Windowpane.Projects
  alias Windowpane.Uploaders.CoverUploader
  alias Windowpane.Uploaders.BannerUploader

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:show_cover_modal, false)
     |> assign(:show_cropper_modal, false)
     |> assign(:cover_uploading, false)
     |> assign(:cover_upload_error, nil)
     |> assign(:show_banner_modal, false)
     |> assign(:show_banner_cropper_modal, false)
     |> assign(:banner_uploading, false)
     |> assign(:banner_upload_error, nil)
     |> assign(:active_tab, "project_details")
     |> assign(:cover_updated_at, System.system_time(:second))
     |> assign(:banner_updated_at, System.system_time(:second))
     |> assign(:saving, false)
     |> assign(:current_price_input, nil)
     |> assign(:current_premiere_price_input, nil)
     |> assign(:current_rental_price_input, nil)
     |> assign(:show_delete_modal, false)
     |> assign(:film_upload_url, nil)
     |> assign(:film_upload_id, nil)
     |> assign(:deleting_film, false)
     |> assign(:trailer_upload_url, nil)
     |> assign(:trailer_upload_id, nil)
     |> assign(:deleting_trailer, false)}
  end

  @impl true
  def update(assigns, socket) do
    require Logger

    project = assigns.project
    editing = assigns.editing

    changeset =
      project
      |> Projects.change_project()
      |> Ecto.Changeset.cast_assoc(:film, with: &Windowpane.Projects.Film.changeset/2)

    # Try to preserve current tab, fallback to assigns, then default
    current_tab = Map.get(socket.assigns, :active_tab)
    active_tab = Map.get(assigns, :active_tab, current_tab || "project_details")

    Logger.info("FilmSetupComponentV2 update - preserving tab: #{active_tab}")

    {:ok,
     socket
     |> assign(:project, project)
     |> assign(:editing, editing)
     |> assign(:changeset, changeset)
     |> assign(:active_tab, active_tab)
     |> allow_upload(:cover, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1)
     |> allow_upload(:banner, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1)}
  end

  @impl true
  def handle_event("save", %{"project" => project_params}, socket) do
    Logger.warning("SAVE: Film Project ID: #{socket.assigns.project.id}, Params: #{inspect(project_params)}")

    # Handle project update with nested film attributes
    case Projects.update_project(socket.assigns.project, project_params) do
      {:ok, project} ->
        updated_project = Projects.get_project_with_film_and_reviews!(project.id)
        send(self(), {:project_updated, updated_project, false})
        Logger.warning("SAVE: Film Project updated successfully")
        {:noreply,
         socket
         |> put_flash(:info, "Film project updated successfully")
         |> assign(:project, updated_project)}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warning("SAVE: Film Project update failed: #{inspect(changeset.errors)}")
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("create_film", _, socket) do
    Logger.warning("CREATE_FILM: Project ID: #{socket.assigns.project.id}")

    # Create film record in database
    film_params = %{
      "project_id" => socket.assigns.project.id,
      "status" => "draft"
    }

    case Projects.create_film(film_params) do
      {:ok, _film_record} ->
        updated_project = Projects.get_project_with_film_and_reviews!(socket.assigns.project.id)
        {:noreply,
         socket
         |> assign(:project, updated_project)
         |> put_flash(:info, "Film created successfully!")}

      {:error, changeset} ->
        Logger.error("Failed to create film record: #{inspect(changeset.errors)}")
        {:noreply, put_flash(socket, :error, "Failed to save film. Please try again.")}
    end
  end

  # Cover upload event handlers
  @impl true
  def handle_event("show_cover_modal", _params, socket) do
    {:noreply, assign(socket, :show_cover_modal, true)}
  end

  @impl true
  def handle_event("hide_cover_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_cover_modal, false)
     |> assign(:cover_upload_error, nil)}
  end

  @impl true
  def handle_event("set_uploading", %{"uploading" => uploading}, socket) do
    # Clear any previous errors when starting a new upload
    socket = if uploading do
      assign(socket, :cover_upload_error, nil)
    else
      socket
    end

    {:noreply, assign(socket, :cover_uploading, uploading)}
  end

  @impl true
  def handle_event("upload_success", _params, socket) do
    updated_project = Projects.get_project_with_film_and_reviews!(socket.assigns.project.id)
    {:noreply,
     socket
     |> assign(:project, updated_project)
     |> assign(:show_cover_modal, false)
     |> assign(:cover_uploading, false)
     |> assign(:cover_upload_error, nil)
     |> assign(:cover_updated_at, System.system_time(:second))
     |> put_flash(:info, "Cover image uploaded successfully!")}
  end

  @impl true
  def handle_event("upload_error", %{"error" => error}, socket) do
    {:noreply,
     socket
     |> assign(:cover_uploading, false)
     |> assign(:cover_upload_error, error)}
  end

  @impl true
  def handle_event("show_film_modal", _params, socket) do
    require Logger
    Logger.info("show_film_modal event received!")
    # Send message to parent to show FilmModalComponent with edit=true
    send(self(), {:show_film_modal, socket.assigns.project, %{edit: true}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    Logger.info("Validating form with params: #{inspect(params)}")
    {:noreply, assign(socket, :live_action_form, params)}
  end

  # Banner upload event handlers (similar to FilmSetupComponent)
  @impl true
  def handle_event("show_banner_modal", _params, socket) do
    {:noreply, assign(socket, :show_banner_modal, true)}
  end

  @impl true
  def handle_event("hide_banner_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_banner_modal, false)
     |> assign(:banner_upload_error, nil)}
  end

  @impl true
  def handle_event("upload_banner", _params, socket) do
    consume_uploaded_entries(socket, :banner, fn %{path: path}, entry ->
      case BannerUploader.store({path, socket.assigns.project}) do
        {:ok, _filename} ->
          {:ok, entry}
        {:error, _reason} ->
          {:error, "Failed to upload banner"}
      end
    end)

    updated_project = Projects.get_project_with_film_and_reviews!(socket.assigns.project.id)

    {:noreply,
     socket
     |> assign(:project, updated_project)
     |> assign(:show_banner_modal, false)
     |> put_flash(:info, "Banner updated successfully")}
  end

  @impl true
  def handle_event("set_banner_uploading", %{"uploading" => uploading}, socket) do
    # Clear any previous errors when starting a new upload
    socket = if uploading do
      assign(socket, :banner_upload_error, nil)
    else
      socket
    end

    {:noreply, assign(socket, :banner_uploading, uploading)}
  end

  @impl true
  def handle_event("banner_upload_success", _params, socket) do
    updated_project = Projects.get_project_with_film_and_reviews!(socket.assigns.project.id)
    {:noreply,
     socket
     |> assign(:project, updated_project)
     |> assign(:show_banner_modal, false)
     |> assign(:banner_uploading, false)
     |> assign(:banner_upload_error, nil)
     |> assign(:banner_updated_at, System.system_time(:second))
     |> put_flash(:info, "Banner image uploaded successfully!")}
  end

  @impl true
  def handle_event("banner_upload_error", %{"error" => error}, socket) do
    {:noreply,
     socket
     |> assign(:banner_uploading, false)
     |> assign(:banner_upload_error, error)}
  end

  # Helper function to generate cache-busting cover URL
  defp cover_url_with_cache_bust(project, cover_updated_at) do
    alias Windowpane.Uploaders.CoverUploader
    base_url = CoverUploader.cover_url(project)
    "#{base_url}?t=#{cover_updated_at}"
  end

  # Helper function to generate cache-busting banner URL
  defp banner_url_with_cache_bust(project, banner_updated_at) do
    alias Windowpane.Uploaders.BannerUploader
    base_url = BannerUploader.banner_url(project)
    "#{base_url}?t=#{banner_updated_at}"
  end

  @impl true
  def handle_event("update_project_details", %{"project" => project_params}, socket) do
    Logger.info("Updating project details: #{inspect(project_params)}")

    # Set saving state to true
    socket = assign(socket, :saving, true)

    # Add a small delay to show the saving indicator
    Process.sleep(300)

    case Projects.update_project(socket.assigns.project, project_params) do
      {:ok, project} ->
        updated_project = Projects.get_project_with_film_and_reviews!(project.id)

        # Send success message to parent
        send(self(), {:flash_message, :info, "Project details updated"})

        {:noreply,
         socket
         |> assign(:project, updated_project)
         |> assign(:changeset, Projects.change_project(updated_project))
         |> assign(:saving, false)}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Send error message to parent
        send(self(), {:flash_message, :error, "Error updating project details"})

        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:saving, false)}
    end
  end

  @impl true
  def handle_event("update_pricing_details", %{"project" => project_params}, socket) do
    Logger.info("Updating pricing details: #{inspect(project_params)}")

    # Set saving state to true
    socket = assign(socket, :saving, true)

    # Add a small delay to show the saving indicator
    Process.sleep(300)

    case Projects.update_project(socket.assigns.project, project_params) do
      {:ok, project} ->
        updated_project = Projects.get_project_with_film_and_reviews!(project.id)

        {:noreply,
         socket
         |> assign(:project, updated_project)
         |> assign(:changeset, Projects.change_project(updated_project))
         |> assign(:saving, false)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:saving, false)}
    end
  end

  @impl true
  def handle_event("deploy", _, socket) do
    project = socket.assigns.project
    Logger.warning("DEPLOY: Starting deployment for Film Project ID: #{project.id}")

    IO.puts("=== FILM DEPLOY DEBUG ===")
    IO.puts("Project ID: #{project.id}")
    IO.puts("Project status: #{project.status}")
    IO.puts("In approval queue: #{Projects.in_approval_queue?(project)}")
    IO.puts("Ready for deployment: #{Projects.ready_for_deployment?(project)}")

    # Check if project is ready for deployment first
    if Projects.ready_for_deployment?(project) do
      Logger.warning("DEPLOY: Film project is ready for deployment")
      case Projects.add_to_approval_queue(project) do
        {:ok, _queue_entry} ->
          # Update project status to waiting for approval
          IO.puts("📝 Updating project status from '#{project.status}' to 'waiting for approval'")
          Logger.warning("DEPLOY: Adding film project to approval queue")
          case Projects.update_project(project, %{status: "waiting for approval"}) do
            {:ok, updated_project} ->
              IO.puts("✅ Project status updated successfully to '#{updated_project.status}'")
              updated_project_with_film = Projects.get_project_with_film_and_reviews!(updated_project.id)
              IO.puts("🔄 Reloaded project with film, status: '#{updated_project_with_film.status}'")

              IO.puts("✅ Film project added to approval queue")
              Logger.warning("DEPLOY: Film project successfully deployed and status updated")

              # Send success message to parent
              send(self(), {:flash_message, :info, "Film project submitted for approval"})

              {:noreply, assign(socket, :project, updated_project_with_film)}

            {:error, changeset} ->
              IO.puts("❌ Failed to update project status: #{inspect(changeset.errors)}")
              Logger.error("DEPLOY: Failed to update project status: #{inspect(changeset.errors)}")

              # Send error message to parent
              send(self(), {:flash_message, :error, "Project submitted but status update failed"})

              {:noreply, assign(socket, :project, project)}
          end
        {:error, _changeset} ->
          IO.puts("❌ Project already in approval queue")
          Logger.warning("DEPLOY: Project already in approval queue")

          # Send error message to parent
          send(self(), {:flash_message, :error, "Project is already in the approval queue"})

          {:noreply, socket}
      end
    else
      # Get specific validation failures
      missing_items = get_deployment_validation_failures(project)

      error_message = if Enum.empty?(missing_items) do
        "Cannot deploy film project. Please check all requirements are met."
      else
        "Cannot deploy film project. Missing: #{Enum.join(missing_items, ", ")}"
      end

      IO.puts("❌ Film project not ready for deployment")
      IO.puts("Missing items: #{inspect(missing_items)}")
      IO.puts("Error message: #{error_message}")
      Logger.warning("DEPLOY: Film project not ready for deployment - Missing: #{inspect(missing_items)}")

      # Send error message to parent
      send(self(), {:flash_message, :error, error_message})

      {:noreply, socket}
    end
  end

  # Helper function to get specific validation failures
  defp get_deployment_validation_failures(project) do
    missing_items = []

    # Check required fields
    missing_items = if field_empty?(project.title), do: ["title" | missing_items], else: missing_items
    missing_items = if field_empty?(project.description), do: ["description" | missing_items], else: missing_items
    missing_items = if field_empty?(project.premiere_date), do: ["premiere date" | missing_items], else: missing_items

    # Check premiere date is in future (only if premiere_date exists)
    missing_items = if project.premiere_date && !premiere_date_in_future?(project.premiere_date), do: ["premiere date must be in future" | missing_items], else: missing_items

    # Check premiere price
    missing_items = if !premiere_price_valid?(project.premiere_price), do: ["premiere price (min $1)" | missing_items], else: missing_items

    # Check uploads
    missing_items = if !Windowpane.Uploaders.CoverUploader.cover_exists?(project), do: ["cover image" | missing_items], else: missing_items
    missing_items = if !Windowpane.Uploaders.BannerUploader.banner_exists?(project), do: ["banner image" | missing_items], else: missing_items

    # Check film video upload
    missing_items = if !film_asset_exists?(project), do: ["film video" | missing_items], else: missing_items

    # Check film-specific validations
    missing_items = if project.film && project.film.rental_enabled && !rental_price_valid?(project.rental_price) do
      ["rental price (min $1, rental enabled)" | missing_items]
    else
      missing_items
    end

    # Debug logging
    IO.puts("VALIDATION DEBUG:")
    IO.puts("- Title empty: #{field_empty?(project.title)}")
    IO.puts("- Description empty: #{field_empty?(project.description)}")
    IO.puts("- Premiere date empty: #{field_empty?(project.premiere_date)}")
    IO.puts("- Premiere date in future: #{if project.premiere_date, do: premiere_date_in_future?(project.premiere_date), else: "N/A"}")
    IO.puts("- Premiere price valid: #{premiere_price_valid?(project.premiere_price)}")
    IO.puts("- Cover exists: #{Windowpane.Uploaders.CoverUploader.cover_exists?(project)}")
    IO.puts("- Banner exists: #{Windowpane.Uploaders.BannerUploader.banner_exists?(project)}")
    IO.puts("- Film asset exists: #{film_asset_exists?(project)}")
    IO.puts("- Rental enabled: #{project.film && project.film.rental_enabled}")
    IO.puts("- Rental price valid: #{if project.film && project.film.rental_enabled, do: rental_price_valid?(project.rental_price), else: "N/A"}")

    Enum.reverse(missing_items)
  end

  # Helper functions for validation
  defp field_empty?(nil), do: true
  defp field_empty?(""), do: true
  defp field_empty?(_), do: false

  defp premiere_date_in_future?(nil), do: false
  defp premiere_date_in_future?(premiere_date) do
    DateTime.compare(premiere_date, DateTime.utc_now()) == :gt
  end

  defp premiere_price_valid?(nil), do: false
  defp premiere_price_valid?(price) when is_number(price), do: price >= 1.0
  defp premiere_price_valid?(price) when is_struct(price, Decimal) do
    Decimal.compare(price, Decimal.new("1.0")) != :lt
  end
  defp premiere_price_valid?(_), do: false

  defp rental_price_valid?(nil), do: false
  defp rental_price_valid?(price) when is_number(price), do: price >= 1.0
  defp rental_price_valid?(price) when is_struct(price, Decimal) do
    Decimal.compare(price, Decimal.new("1.0")) != :lt
  end
  defp rental_price_valid?(_), do: false

  defp film_asset_exists?(project) do
    project.film &&
    project.film.film_asset_id &&
    project.film.film_asset_id != "" &&
    project.film.film_playback_id &&
    project.film.film_playback_id != ""
  end

  @impl true
  def handle_event("show_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, true)}
  end

  @impl true
  def handle_event("hide_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, false)}
  end

  @impl true
  def handle_event("delete_project", _params, socket) do
    require Logger
    Logger.info("Deleting project: #{socket.assigns.project.id}")

    socket = assign(socket, :show_delete_modal, false)

    case Projects.delete_project(socket.assigns.project) do
      {:ok, _project} ->
        Logger.info("Project deleted successfully")
        # Send message to parent to redirect after deletion
        send(self(), {:project_deleted})

        {:noreply, socket}

      {:error, changeset} ->
        Logger.error("Failed to delete project: #{inspect(changeset.errors)}")

        # Send error message to parent
        send(self(), {:flash_message, :error, "Failed to delete project"})

        {:noreply, socket}
    end
  end

  # Film upload event handlers
  @impl true
  def handle_event("init_film_upload", _, socket) do
    IO.puts("=== INIT_FILM_UPLOAD DEBUG ===")
    IO.puts("Event handler triggered!")
    IO.puts("Project ID: #{socket.assigns.project.id}")

    Logger.warning("INIT_FILM_UPLOAD: Project ID: #{socket.assigns.project.id}")
    Logger.warning("INIT_FILM_UPLOAD: Event received successfully!")

    IO.puts("Creating Mux client...")
    client = Mux.client()
    IO.puts("Mux client created: #{inspect(client)}")

    params = %{
      "new_asset_settings" => %{
        "playback_policies" => ["signed"],
        "passthrough" => "type:film;project_id:#{socket.assigns.project.id}",
      },
      "cors_origin" => Application.get_env(:windowpane, :cors_origin_urls)[:studio_app],
    }

    IO.puts("Mux params: #{inspect(params)}")
    IO.puts("Attempting to create Mux upload...")

    case Mux.Video.Uploads.create(client, params) do
      {:ok, %{"url" => url, "id" => id}, _env} ->
        IO.puts("✅ Mux Upload URL: #{url}")
        IO.puts("✅ Upload ID: #{id}")

        # Get or create film for this project and update it with film upload ID
        film = Projects.get_or_create_film(socket.assigns.project)
        case Projects.update_film(film, %{
          "film_upload_id" => id
        }) do
          {:ok, _updated_film} ->
            updated_project = Projects.get_project_with_film_and_reviews!(socket.assigns.project.id)
            IO.puts("✅ Film upload ID saved successfully")
            {:noreply,
             socket
             |> assign(:project, updated_project)
             |> assign(:film_upload_url, url)
             |> assign(:film_upload_id, id)
             |> put_flash(:info, "Upload URL generated")}

          {:error, changeset} ->
            IO.puts("❌ Failed to save upload ID: #{inspect(changeset)}")
            {:noreply, put_flash(socket, :error, "Failed to save upload URL")}
        end

      error ->
        IO.puts("❌ Upload creation failed: #{inspect(error)}")
        IO.inspect(error, label: "Upload creation failed")
        {:noreply, put_flash(socket, :error, "Failed to generate upload URL")}
    end
  end

  @impl true
  def handle_event("delete_film_asset", _, socket) do
    project = socket.assigns.project

    if project.film && project.film.film_asset_id do
      Logger.info("Deleting film asset: #{project.film.film_asset_id}")

      socket = assign(socket, :deleting_film, true)

      client = Mux.client()

      case Mux.Video.Assets.delete(client, project.film.film_asset_id) do
        {:ok, _response, _env} ->
          # Clear the asset and playback IDs from the database
          case Projects.update_film(project.film, %{
            "film_asset_id" => nil,
            "film_playback_id" => nil,
            "film_upload_id" => nil,
            "duration" => nil
          }) do
            {:ok, _updated_film} ->
              updated_project = Projects.get_project_with_film_and_reviews!(project.id)

              # Send success message to parent
              send(self(), {:flash_message, :info, "Film video deleted successfully"})

              {:noreply,
               socket
               |> assign(:project, updated_project)
               |> assign(:deleting_film, false)
               |> assign(:film_upload_url, nil)
               |> assign(:film_upload_id, nil)}

            {:error, changeset} ->
              Logger.error("Failed to update film record after asset deletion: #{inspect(changeset.errors)}")

              # Send error message to parent
              send(self(), {:flash_message, :error, "Asset deleted from Mux but failed to update database"})

              {:noreply, assign(socket, :deleting_film, false)}
          end

        {:error, reason} ->
          Logger.error("Failed to delete Mux asset: #{inspect(reason)}")

          # Send error message to parent
          send(self(), {:flash_message, :error, "Failed to delete film video"})

          {:noreply, assign(socket, :deleting_film, false)}
      end
    else
      Logger.warning("No film asset to delete for project: #{project.id}")

      # Send error message to parent
      send(self(), {:flash_message, :error, "No film video to delete"})

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("film_upload_error", %{"error" => error}, socket) do
    Logger.error("Film upload error: #{error}")

    # Send error message to parent
    send(self(), {:flash_message, :error, "Film upload failed: #{error}"})

    {:noreply, socket}
  end

  @impl true
  def handle_event("film_upload_success", params, socket) do
    Logger.info("Film upload success: #{inspect(params)}")

    # The upload is complete, but we need to wait for Mux webhook to process the asset
    # For now, just show a success message
    send(self(), {:flash_message, :info, "Film upload completed! Processing video..."})

    {:noreply, socket}
  end

  # Trailer upload event handlers
  @impl true
  def handle_event("init_trailer_upload", _, socket) do
    IO.puts("=== INIT_TRAILER_UPLOAD DEBUG ===")
    IO.puts("Event handler triggered!")
    IO.puts("Project ID: #{socket.assigns.project.id}")

    Logger.warning("INIT_TRAILER_UPLOAD: Project ID: #{socket.assigns.project.id}")
    Logger.warning("INIT_TRAILER_UPLOAD: Event received successfully!")

    IO.puts("Creating Mux client...")
    client = Mux.client()
    IO.puts("Mux client created: #{inspect(client)}")

    params = %{
      "new_asset_settings" => %{
        "playback_policies" => ["public"],
        "passthrough" => "type:trailer;project_id:#{socket.assigns.project.id}",
      },
      "cors_origin" => Application.get_env(:windowpane, :cors_origin_urls)[:studio_app],
    }

    IO.puts("Mux params: #{inspect(params)}")
    IO.puts("Attempting to create Mux upload...")

    case Mux.Video.Uploads.create(client, params) do
      {:ok, %{"url" => url, "id" => id}, _env} ->
        IO.puts("✅ Mux Upload URL: #{url}")
        IO.puts("✅ Upload ID: #{id}")

        # Get or create film for this project and update it with trailer upload ID
        film = Projects.get_or_create_film(socket.assigns.project)
        case Projects.update_film(film, %{
          "trailer_upload_id" => id
        }) do
          {:ok, _updated_film} ->
            updated_project = Projects.get_project_with_film_and_reviews!(socket.assigns.project.id)
            IO.puts("✅ Trailer upload ID saved successfully")

            {:noreply,
             socket
             |> assign(:project, updated_project)
             |> assign(:trailer_upload_url, url)
             |> assign(:trailer_upload_id, id)
             |> put_flash(:info, "Trailer upload URL generated")}

          {:error, changeset} ->
            IO.puts("❌ Failed to save trailer upload ID: #{inspect(changeset)}")
            {:noreply, put_flash(socket, :error, "Failed to save trailer upload URL")}
        end

      error ->
        IO.puts("❌ Trailer upload creation failed: #{inspect(error)}")
        IO.inspect(error, label: "Trailer upload creation failed")
        {:noreply, put_flash(socket, :error, "Failed to generate trailer upload URL")}
    end
  end

  @impl true
  def handle_event("delete_trailer_asset", _, socket) do
    project = socket.assigns.project

    if project.film && project.film.trailer_asset_id do
      Logger.info("Deleting trailer asset: #{project.film.trailer_asset_id}")

      socket = assign(socket, :deleting_trailer, true)

      client = Mux.client()

      case Mux.Video.Assets.delete(client, project.film.trailer_asset_id) do
        {:ok, _response, _env} ->
          # Clear the trailer asset and playback IDs from the database
          case Projects.update_film(project.film, %{
            "trailer_asset_id" => nil,
            "trailer_playback_id" => nil,
            "trailer_upload_id" => nil
          }) do
            {:ok, _updated_film} ->
              updated_project = Projects.get_project_with_film_and_reviews!(project.id)

              # Send success message to parent
              send(self(), {:flash_message, :info, "Trailer video deleted successfully"})

              {:noreply,
               socket
               |> assign(:project, updated_project)
               |> assign(:deleting_trailer, false)
               |> assign(:trailer_upload_url, nil)
               |> assign(:trailer_upload_id, nil)}

            {:error, changeset} ->
              Logger.error("Failed to update film record after trailer asset deletion: #{inspect(changeset.errors)}")

              # Send error message to parent
              send(self(), {:flash_message, :error, "Trailer deleted from Mux but failed to update database"})

              {:noreply, assign(socket, :deleting_trailer, false)}
          end

        {:error, reason} ->
          Logger.error("Failed to delete Mux trailer asset: #{inspect(reason)}")

          # Send error message to parent
          send(self(), {:flash_message, :error, "Failed to delete trailer video"})

          {:noreply, assign(socket, :deleting_trailer, false)}
      end
    else
      Logger.warning("No trailer asset to delete for project: #{project.id}")

      # Send error message to parent
      send(self(), {:flash_message, :error, "No trailer video to delete"})

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("trailer_upload_error", %{"error" => error}, socket) do
    Logger.error("Trailer upload error: #{error}")

    # Send error message to parent
    send(self(), {:flash_message, :error, "Trailer upload failed: #{error}"})

    {:noreply, socket}
  end

  @impl true
  def handle_event("trailer_upload_success", params, socket) do
    Logger.info("Trailer upload success: #{inspect(params)}")

    # The upload is complete, but we need to wait for Mux webhook to process the asset
    # For now, just show a success message
    send(self(), {:flash_message, :info, "Trailer upload completed! Processing video..."})

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto">
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- Main Content (Left Side) -->
        <div class="lg:col-span-2">
          <!-- Tab Navigation -->
          <div class="bg-gray-900 shadow mb-8" style="border: 4px solid white;">
            <div class="border-b border-gray-200">
              <nav class="-mb-px flex">
                <button
                  phx-click="switch_tab"
                  phx-value-tab="project_details"
                  phx-target={@myself}
                  class={[
                    "py-4 px-6 text-sm font-medium border-b-2 transition-colors",
                    if(@active_tab == "project_details",
                      do: "border-blue-500 text-white font-semibold",
                      else: "border-transparent text-white hover:scale-105 transition-all duration-150"
                    )
                  ]}
                >
                  Project Details
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="ui_setup"
                  phx-target={@myself}
                  class={[
                    "py-4 px-6 text-sm font-medium border-b-2 transition-colors",
                    if(@active_tab == "ui_setup",
                      do: "border-blue-500 text-white font-semibold",
                      else: "border-transparent text-white hover:scale-105 transition-all duration-150"
                    )
                  ]}
                >
                  UI Setup
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="film_upload"
                  phx-target={@myself}
                  class={[
                    "py-4 px-6 text-sm font-medium border-b-2 transition-colors",
                    if(@active_tab == "film_upload",
                      do: "border-blue-500 text-white font-semibold",
                      else: "border-transparent text-white hover:scale-105 transition-all duration-150"
                    )
                  ]}
                >
                  Film Upload
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="trailer_upload"
                  phx-target={@myself}
                  class={[
                    "py-4 px-6 text-sm font-medium border-b-2 transition-colors",
                    if(@active_tab == "trailer_upload",
                      do: "border-blue-500 text-white font-semibold",
                      else: "border-transparent text-white hover:scale-105 transition-all duration-150"
                    )
                  ]}
                >
                  Trailer Upload
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="pricing_details"
                  phx-target={@myself}
                  class={[
                    "py-4 px-6 text-sm font-medium border-b-2 transition-colors",
                    if(@active_tab == "pricing_details",
                      do: "border-blue-500 text-white font-semibold",
                      else: "border-transparent text-white hover:scale-105 transition-all duration-150"
                    )
                  ]}
                >
                  Pricing Details
                </button>
              </nav>
            </div>
          </div>

          <!-- Tab Content -->
          <%= if @active_tab == "project_details" do %>
            <!-- Project Details Tab -->
            <div class="bg-gray-900 shadow p-6 mb-8" style="border: 4px solid white;">
              <h2 class="text-2xl text-white font-bold mb-6">Project Details</h2>

              <.form :let={f} for={@changeset} phx-change="update_project_details" phx-target={@myself} class="space-y-6">
                <label class="text-white font-semibold text-md">Film Title</label>
                <div>
                  <.input field={f[:title]} type="text" required />
                </div>
                <label class="block text-white font-semibold text-md mt-10">
                  Film Description
                </label>
                <div>
                  <.input field={f[:description]} type="textarea" rows="4" />
                </div>
                <label class="block text-white font-semibold text-md mt-10">
                  Scheduled Premiere Date (UTC)
                </label>
                <div>
                  <.input field={f[:premiere_date]} type="datetime-local" />
                </div>

                <div class="flex items-center justify-end">
                  <%= if @saving do %>
                    <div class="flex items-center gap-2">
                      <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                      <span class="text-sm text-gray-500">Saving...</span>
                    </div>
                  <% else %>
                    <div class="flex items-center gap-2">
                      <div class="w-2 h-2 bg-green-500 rounded-full"></div>
                      <span class="text-sm text-gray-500">All changes saved</span>
                    </div>
                  <% end %>
                </div>
              </.form>
            </div>
          <% end %>

          <%= if @active_tab == "pricing_details" do %>
            <!-- Pricing Details Tab -->
            <div class="bg-gray-900 shadow p-6 mb-8" style="border: 4px solid white;">
              <h2 class="text-2xl text-white font-bold mb-6">Pricing Details</h2>

              <.form :let={f} for={@changeset} phx-change="update_pricing_details" phx-target={@myself} class="space-y-6">
                <label class="text-white font-semibold text-md">Premiere Ticket Price ($)</label>
                <div>
                  <.input field={f[:premiere_price]} type="number" min="1.00" step="0.01" />
                </div>

                <label class="block text-white font-semibold text-md mt-10">
                  Rental Ticket Price ($)
                </label>
                <div>
                  <.input field={f[:rental_price]} type="number" min="1.00" step="0.01" />
                </div>

                <div class="flex items-center justify-end">
                  <%= if @saving do %>
                    <div class="flex items-center gap-2">
                      <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                      <span class="text-sm text-gray-500">Saving...</span>
                    </div>
                  <% else %>
                    <div class="flex items-center gap-2">
                      <div class="w-2 h-2 bg-green-500 rounded-full"></div>
                      <span class="text-sm text-gray-500">All changes saved</span>
                    </div>
                  <% end %>
                </div>
              </.form>
            </div>
          <% end %>
          <script src="https://cdn.jsdelivr.net/npm/@mux/mux-uploader"></script>
          <%= if @active_tab == "film_upload" do %>
            <!-- Film Upload Tab -->
            <div class="bg-gray-900 shadow p-6 mb-8" style="border: 4px solid white;">
              <h2 class="text-2xl text-white font-bold mb-6 flex items-center">
                Film Upload
                <%= if @project.film && @project.film.film_asset_id && @project.film.film_asset_id != "" && @project.film.film_playback_id && @project.film.film_playback_id != "" do %>
                  <svg class="ml-2 h-5 w-5 text-green-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
                  </svg>
                <% end %>
              </h2>

              <div class="space-y-6">
                <%= if @project.film && @project.film.film_asset_id && @project.film.film_asset_id != "" do %>
                  <!-- Film is already uploaded -->
                  <div class="bg-green-50 border border-green-200 rounded-lg p-6">
                    <div class="flex items-center">
                      <svg class="h-8 w-8 text-green-500 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <div>
                        <h3 class="text-lg font-medium text-green-800">Film Uploaded Successfully</h3>
                        <p class="text-sm text-green-600 mt-1">
                          Your film video has been uploaded and processed by Mux.
                          <%= if @project.film.duration do %>
                            Duration: <%= @project.film.duration %> minutes.
                          <% end %>
                        </p>
                      </div>
                    </div>

                    <div class="mt-4 flex gap-3">
                      <button
                        type="button"
                        phx-click="delete_film_asset"
                        phx-target={@myself}
                        class={[
                          "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-red-700 bg-red-100 hover:bg-red-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500",
                          @deleting_film && "opacity-50 cursor-not-allowed"
                        ]}
                        disabled={@deleting_film}
                      >
                        <%= if @deleting_film do %>
                          <svg class="animate-spin -ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                            <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                          </svg>
                          Deleting...
                        <% else %>
                          <svg class="mr-2 -ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                          </svg>
                          Delete Film Video
                        <% end %>
                      </button>
                    </div>
                  </div>
                <% else %>
                  <!-- No film uploaded yet -->
                  <div class="text-center">
                    <div class="border-2 border-dashed border-gray-300 rounded-lg p-12">
                      <svg class="mx-auto h-12 w-12 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2m0 0V1a1 1 0 011 1v3M7 4V1a1 1 0 011-1h8a1 1 0 011 1v3m-9 4l4 4m0 0l4-4m-4 4V8" />
                      </svg>
                      <h3 class="text-lg font-medium text-white mb-2">Upload Your Film</h3>
                      <p class="text-gray-300 text-sm mb-6">
                        Upload your film video file. Supported formats: MP4, MOV, AVI, and more.
                      </p>
                      <%= if @film_upload_url do %>
                        <div id="mux-film-upload-container" phx-update="ignore">
                          <style>
                            mux-uploader {
                            --progress-bar-fill-color: #0000FF;
                              color: white;
                            }
                            .btn {
                              padding: 6px 8px;
                              border: 1px solid #0d9488;
                              border-radius: 5px;
                              font-size: 16px;
                              color: white;
                              background: black;
                              cursor: pointer;
                            }
                          </style>
                          <mux-uploader no-drop endpoint={@film_upload_url}>
                          </mux-uploader>
                          <script>
                            setTimeout(() => {
                              console.log('=== MUX UPLOADER DEBUG ===');
                              const uploader = document.querySelector('mux-uploader');
                              console.log('Mux uploader element:', uploader);
                              console.log('customElements.get("mux-uploader"):', customElements.get('mux-uploader'));

                              if (uploader) {
                                console.log('Mux uploader found, endpoint:', uploader.endpoint);
                                console.log('Uploader attributes:', {
                                  endpoint: uploader.getAttribute('endpoint'),
                                  id: uploader.id,
                                  className: uploader.className
                                });

                                // Test if the button inside works
                                const button = uploader.querySelector('button[slot="file-select"]');
                                console.log('File select button:', button);

                                if (button) {
                                  button.addEventListener('click', (e) => {
                                    console.log('File select button clicked!', e);
                                  });
                                }

                                uploader.addEventListener('file-selected', (e) => {
                                  console.log('File selected:', e.detail);
                                });
                                uploader.addEventListener('uploadstart', (e) => {
                                  console.log('Upload started:', e.detail);
                                });
                                uploader.addEventListener('progress', (e) => {
                                  console.log('Upload progress:', e.detail);
                                });
                                uploader.addEventListener('success', (e) => {
                                  console.log('Upload success:', e.detail);
                                });
                                uploader.addEventListener('error', (e) => {
                                  console.log('Upload error:', e.detail);
                                });
                              } else {
                                console.error('Mux uploader not found!');
                              }
                            }, 1000);
                          </script>
                        </div>
                      <% end %>
                      <%= if @film_upload_url == nil do %>
                      <button
                        type="button"
                        phx-click="init_film_upload"
                        phx-target={@myself}
                        class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                      >
                        <svg class="mr-2 -ml-1 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                        </svg>
                          Start Film Upload
                      </button>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <%= if @active_tab == "trailer_upload" do %>
            <!-- Trailer Upload Tab -->
            <div class="bg-gray-900 shadow p-6 mb-8" style="border: 4px solid white;">
              <h2 class="text-2xl text-white font-bold mb-6 flex items-center">
                Trailer Upload
                <%= if @project.film && @project.film.trailer_asset_id && @project.film.trailer_asset_id != "" && @project.film.trailer_playback_id && @project.film.trailer_playback_id != "" do %>
                  <svg class="ml-2 h-5 w-5 text-green-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
                  </svg>
                <% end %>
              </h2>

              <div class="space-y-6">
                <%= if @project.film && @project.film.trailer_asset_id && @project.film.trailer_asset_id != "" do %>
                  <!-- Trailer is already uploaded -->
                  <div class="bg-green-50 border border-green-200 rounded-lg p-6">
                    <div class="flex items-center">
                      <svg class="h-8 w-8 text-green-500 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <div>
                        <h3 class="text-lg font-medium text-green-800">Trailer Uploaded Successfully</h3>
                        <p class="text-sm text-green-600 mt-1">
                          Your trailer video has been uploaded and processed by Mux.
                        </p>
                      </div>
                    </div>

                    <div class="mt-4 flex gap-3">
                      <button
                        type="button"
                        phx-click="delete_trailer_asset"
                        phx-target={@myself}
                        class={[
                          "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-red-700 bg-red-100 hover:bg-red-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500",
                          @deleting_trailer && "opacity-50 cursor-not-allowed"
                        ]}
                        disabled={@deleting_trailer}
                      >
                        <%= if @deleting_trailer do %>
                          <svg class="animate-spin -ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                            <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                          </svg>
                          Deleting...
                        <% else %>
                          <svg class="mr-2 -ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                          </svg>
                          Delete Trailer Video
                        <% end %>
                      </button>
                    </div>
                  </div>
                <% else %>
                  <!-- No trailer uploaded yet -->
                  <div class="text-center">
                    <div class="border-2 border-dashed border-gray-300 rounded-lg p-12">
                      <svg class="mx-auto h-12 w-12 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2m0 0V1a1 1 0 011 1v3M7 4V1a1 1 0 011-1h8a1 1 0 011 1v3m-9 4l4 4m0 0l4-4m-4 4V8" />
                      </svg>
                      <h3 class="text-lg font-medium text-white mb-2">Upload Your Trailer</h3>
                      <p class="text-gray-300 text-sm mb-6">
                        Upload your trailer video file. Supported formats: MP4, MOV, AVI, and more.
                      </p>
                      <%= if @trailer_upload_url do %>
                        <div id="mux-trailer-upload-container" phx-update="ignore">
                          <style>
                            #mux-trailer-upload-container mux-uploader {
                            --progress-bar-fill-color: #0000FF;
                              color: white;
                            }
                            .btn {
                              padding: 6px 8px;
                              border: 1px solid #0d9488;
                              border-radius: 5px;
                              font-size: 16px;
                              color: white;
                              background: black;
                              cursor: pointer;
                            }
                          </style>
                          <mux-uploader no-drop endpoint={@trailer_upload_url}>
                          </mux-uploader>
                          <script>
                            setTimeout(() => {
                              console.log('=== MUX TRAILER UPLOADER DEBUG ===');
                              const uploader = document.querySelector('#mux-trailer-upload-container mux-uploader');
                              console.log('Mux trailer uploader element:', uploader);
                              console.log('customElements.get("mux-uploader"):', customElements.get('mux-uploader'));

                              if (uploader) {
                                console.log('Mux trailer uploader found, endpoint:', uploader.endpoint);
                                console.log('Uploader attributes:', {
                                  endpoint: uploader.getAttribute('endpoint'),
                                  id: uploader.id,
                                  className: uploader.className
                                });

                                // Test if the button inside works
                                const button = uploader.querySelector('button[slot="file-select"]');
                                console.log('Trailer file select button:', button);

                                if (button) {
                                  button.addEventListener('click', (e) => {
                                    console.log('Trailer file select button clicked!', e);
                                  });
                                }

                                uploader.addEventListener('file-selected', (e) => {
                                  console.log('Trailer file selected:', e.detail);
                                });
                                uploader.addEventListener('uploadstart', (e) => {
                                  console.log('Trailer upload started:', e.detail);
                                });
                                uploader.addEventListener('progress', (e) => {
                                  console.log('Trailer upload progress:', e.detail);
                                });
                                uploader.addEventListener('success', (e) => {
                                  console.log('Trailer upload success:', e.detail);
                                });
                                uploader.addEventListener('error', (e) => {
                                  console.log('Trailer upload error:', e.detail);
                                });
                              } else {
                                console.error('Mux trailer uploader not found!');
                              }
                            }, 1000);
                          </script>
                        </div>
                      <% end %>
                      <%= if @trailer_upload_url == nil do %>
                      <button
                        type="button"
                        phx-click="init_trailer_upload"
                        phx-target={@myself}
                        class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
                      >
                        <svg class="mr-2 -ml-1 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                        </svg>
                          Start Trailer Upload
                      </button>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <%= if @active_tab == "ui_setup" do %>
            <!-- Cover Image Section -->
            <div class="bg-gray-900 shadow p-6 mt-8" style="border: 4px solid white;">
              <h3 class="text-xl text-white font-bold mb-4">User Interface Setup</h3>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
                <!-- Cover Upload Section -->
                <div>
                  <h4 class="text-lg text-white font-semibold mb-4">Cover Image</h4>
                  <div class="flex justify-center">
                    <!-- Container for cover and edit button -->
                    <div class="relative flex flex-col items-center">
                      <!-- Film Cover Placeholder with Dashed Border -->
                      <div
                        class="w-64 aspect-square border-2 border-dashed border-gray-300 rounded-lg flex flex-col items-center justify-center bg-gray-50 hover:border-gray-400 hover:bg-gray-100 transition-colors cursor-pointer"
                      >
                        <%= if Windowpane.Uploaders.CoverUploader.cover_exists?(@project) do %>
                          <!-- Show uploaded cover image -->
                          <img
                            src={cover_url_with_cache_bust(@project, @cover_updated_at)}
                            alt={"Cover for #{@project.title}"}
                            class="w-full h-full object-cover rounded-lg"
                          />
                        <% else %>
                          <!-- Show placeholder when no cover exists -->
                          <div class="text-center">
                            <svg class="mx-auto h-12 w-12 text-gray-400 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                            </svg>
                            <p class="text-xs text-gray-500">1:1 Aspect Ratio</p>
                            <p class="text-xs text-gray-400">JPG, PNG, WEBP</p>
                          </div>
                        <% end %>
                      </div>

                      <!-- Pencil Edit Icon -->
                      <button
                        type="button"
                        class="absolute top-0 right-0 -mt-2 -mr-2 w-8 h-8 bg-white rounded-full shadow-md flex items-center justify-center border border-gray-200 hover:bg-gray-50 cursor-pointer z-10"
                        phx-click="show_cover_modal"
                        phx-target={@myself}
                      >
                        <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                        </svg>
                      </button>
                    </div>
                  </div>
                  <p class="text-sm text-gray-600 text-center mt-4">
                    Cover image for your film (1:1 aspect ratio)
                  </p>
                </div>

                <!-- Banner Upload Section -->
                <div>
                  <h4 class="text-lg text-white font-semibold mb-4">Banner Image</h4>
                  <div class="flex justify-center">
                    <!-- Container for banner and edit button -->
                    <div class="relative flex flex-col items-center">
                      <!-- Banner Placeholder with Dashed Border -->
                      <div
                        class="w-80 aspect-video border-2 border-dashed border-gray-300 rounded-lg flex flex-col items-center justify-center bg-gray-50 hover:border-gray-400 hover:bg-gray-100 transition-colors cursor-pointer"
                      >
                        <%= if BannerUploader.banner_exists?(@project) do %>
                          <!-- Show uploaded banner image -->
                          <img
                            src={banner_url_with_cache_bust(@project, @banner_updated_at)}
                            alt={"Banner for #{@project.title}"}
                            class="w-full h-full object-cover rounded-lg"
                          />
                        <% else %>
                          <!-- Show placeholder when no banner exists -->
                          <div class="text-center">
                            <svg class="mx-auto h-12 w-12 text-gray-400 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                            </svg>
                            <p class="text-xs text-gray-500">16:9 Aspect Ratio</p>
                            <p class="text-xs text-gray-400">JPG, PNG, WEBP</p>
                          </div>
                        <% end %>
                      </div>

                      <!-- Pencil Edit Icon -->
                      <button
                        type="button"
                        class="absolute top-0 right-0 -mt-2 -mr-2 w-8 h-8 bg-white rounded-full shadow-md flex items-center justify-center border border-gray-200 hover:bg-gray-50 cursor-pointer z-10"
                        phx-click="show_banner_modal"
                        phx-target={@myself}
                      >
                        <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                        </svg>
                      </button>
                    </div>
                  </div>
                  <p class="text-sm text-gray-600 text-center mt-4">
                    Banner image for your film (16:9 aspect ratio)
                  </p>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Sidebar (Right Side) -->
        <div class="lg:col-span-1">
          <!-- Actions Section -->
          <div class="bg-gray-900 shadow p-6 mb-8" style="border: 4px solid white;">
            <h2 class="text-xl text-white font-bold mb-4">Actions</h2>
            <div class="space-y-4">
              <%= if @project.status == "draft" or @project.status == "waiting for approval" do %>
                <button
                  phx-click="deploy"
                  phx-target={@myself}
                  class="w-full inline-flex justify-center items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 disabled:bg-gray-400 disabled:cursor-not-allowed"
                  disabled={@project.status == "waiting for approval" or Projects.in_approval_queue?(@project)}
                >
                  <svg class="mr-2 -ml-1 h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                  </svg>
                  <%= cond do %>
                    <% @project.status == "waiting for approval" -> %>
                      Pending Approval
                    <% Projects.in_approval_queue?(@project) -> %>
                      Pending Approval
                    <% true -> %>
                      Submit for Approval
                  <% end %>
                </button>
              <% else %>
                <!-- Project is already deployed -->
                <div class="w-full inline-flex items-center justify-center px-4 py-2 text-sm text-green-600 bg-green-50 rounded-md border border-green-200">
                  <svg class="mr-2 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                  Project Deployed
                </div>
              <% end %>
            </div>
          </div>

          <!-- Reviews Section (Only render if reviews exist) -->
          <%= if @project.reviews && length(@project.reviews) > 0 do %>
            <div class="bg-gray-900 shadow p-6 mb-8" style="border: 4px solid white;">
              <h2 class="text-xl text-white font-bold mb-4">Reviews</h2>
              <div class="space-y-4">
                <%= for review <- @project.reviews do %>
                  <div class="bg-gray-800 rounded-lg p-4 border border-gray-600">
                    <div class="flex items-center justify-between mb-2">
                      <div class="flex items-center">
                        <div class="flex items-center">
                          <%= for i <- 1..5 do %>
                            <%= if i <= review.rating do %>
                              <svg class="h-4 w-4 text-yellow-400 fill-current" viewBox="0 0 20 20">
                                <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                              </svg>
                            <% else %>
                              <svg class="h-4 w-4 text-gray-600 fill-current" viewBox="0 0 20 20">
                                <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                              </svg>
                            <% end %>
                          <% end %>
                        </div>
                        <span class="ml-2 text-sm text-gray-300">
                          <%= review.rating %>/5
                        </span>
                      </div>
                      <span class="text-xs text-gray-400">
                        <%= Calendar.strftime(review.inserted_at, "%B %d, %Y") %>
                      </span>
                    </div>
                    <%= if review.comment && review.comment != "" do %>
                      <p class="text-gray-300 text-sm">
                        <%= review.comment %>
                      </p>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
