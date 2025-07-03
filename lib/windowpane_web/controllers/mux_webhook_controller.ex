defmodule WindowpaneWeb.MuxWebhookController do
  use WindowpaneWeb, :controller
  require Logger

  alias Windowpane.Projects

  def create(conn, %{"type" => event_type} = params) do
    case handle_event(event_type, params) do
      :ok ->
        send_resp(conn, 200, "OK")
      {:error, reason} ->
        Logger.error("Failed to handle webhook: #{inspect(reason)}")
        send_resp(conn, 500, "Failed to process webhook")
    end
  end

  def create(conn, params) do
    Logger.error("Invalid webhook payload: #{inspect(params)}")
    send_resp(conn, 400, "Invalid webhook payload")
  end

  defp handle_event("video.asset.ready", %{"data" => %{"id" => asset_id, "playback_ids" => [%{"id" => playback_id} | _]}} = params) do
    Logger.info("Asset ready: #{asset_id}, playback_id: #{playback_id}")

    # Extract project_id and type from passthrough
    passthrough = get_in(params, ["data", "passthrough"])

    if is_binary(passthrough) && String.contains?(passthrough, "type:live_stream;") do
      Logger.info("Asset ready event for live_stream type, skipping processing")
      :ok
    else
      if is_binary(passthrough) do
        case parse_passthrough(passthrough) do
          {:ok, %{"project_id" => project_id, "type" => type}} ->
            handle_asset_ready_with_project_id(asset_id, playback_id, project_id, type)
          {:error, reason} ->
            Logger.error("Failed to parse passthrough in asset ready: #{inspect(reason)}")
            handle_asset_ready_fallback(asset_id, playback_id)
        end
      else
        # Fallback: find project by asset_id (original logic)
        Logger.warning("Asset ready event missing passthrough: #{asset_id}, falling back to asset_id lookup")
        handle_asset_ready_fallback(asset_id, playback_id)
      end
    end
  end

  defp handle_event("video.asset.errored", %{"data" => %{"id" => asset_id, "errors" => %{"messages" => messages}}} = params) do
    Logger.error("Asset errored: #{asset_id}, messages: #{inspect(messages)}")

    # Extract project_id from passthrough if available for better error tracking
    passthrough = get_in(params, ["data", "passthrough"])

    if is_binary(passthrough) do
      case parse_passthrough(passthrough) do
        {:ok, %{"project_id" => project_id}} ->
          Logger.error("Asset error for project #{project_id}: #{inspect(messages)}")
        {:error, _reason} ->
          Logger.error("Asset error (unable to parse project_id from passthrough): #{inspect(messages)}")
      end
    else
      Logger.error("Asset error (no passthrough available): #{inspect(messages)}")
    end

    :ok
  end

  defp handle_event("video.asset.live_stream_completed", %{"data" => %{"id" => asset_id}, "passthrough" => passthrough} = params) do
    Logger.info("Live stream completed: #{asset_id}")

    case parse_passthrough(passthrough) do
      {:ok, %{"project_id" => project_id, "type" => "live_stream"}} ->
        Logger.info("Live stream completed for project #{project_id} with type 'live_stream'")

        # Update project type from live_stream to film
        case Projects.get_project!(project_id) do
          project when not is_nil(project) ->
            case Projects.update_project(project, %{type: "film"}) do
              {:ok, updated_project} ->
                Logger.info("Successfully updated project #{project_id} type from 'live_stream' to 'film'")
                :ok
              {:error, changeset} ->
                Logger.error("Failed to update project #{project_id} type to 'film': #{inspect(changeset.errors)}")
                {:error, :project_update_failed}
            end
          nil ->
            Logger.error("Project #{project_id} not found")
            {:error, :project_not_found}
        end

      {:ok, %{"project_id" => project_id, "type" => other_type}} ->
        Logger.info("Live stream completed for project #{project_id} with type '#{other_type}' (not live_stream), skipping type update")
        :ok

      {:ok, %{"project_id" => project_id}} ->
        Logger.warning("Live stream completed for project #{project_id} but no type found in passthrough")
        :ok

      {:error, reason} ->
        Logger.error("Failed to parse passthrough in live stream completed: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Error handling live stream completed event: #{inspect(e)}")
      {:error, :unexpected_error}
  end

  defp handle_event("video.live_stream.connected", %{"data" => %{"active_asset_id" => asset_id, "playback_ids" => [%{"id" => playback_id} | _]}} = params) do
    Logger.info("Live stream connected: #{asset_id}, playback_id: #{playback_id}")

    # Extract project_id and type from passthrough
    passthrough = get_in(params, ["data", "passthrough"])

    if is_binary(passthrough) do
      case parse_passthrough(passthrough) do
        {:ok, %{"project_id" => project_id, "type" => "live_stream"}} ->
          handle_asset_ready_with_project_id(asset_id, playback_id, project_id, "film", false)
        {:error, reason} ->
          Logger.error("Failed to parse passthrough in asset ready: #{inspect(reason)}")
          handle_asset_ready_fallback(asset_id, playback_id)
      end
    else
      # Fallback: find project by asset_id (original logic)
      Logger.warning("Asset ready event missing passthrough: #{asset_id}, falling back to asset_id lookup")
      handle_asset_ready_fallback(asset_id, playback_id)
    end
  end

  defp handle_event("video.asset.errored", %{"data" => %{"id" => asset_id}} = params) do
    Logger.error("Asset errored: #{asset_id}, but no error messages found in payload: #{inspect(params)}")
    :ok
  end

  defp handle_event(event_type, params) do
    Logger.info("Unhandled webhook event: #{event_type}, params: #{inspect(params)}")
    :ok
  end

  defp parse_passthrough(passthrough) do
    try do
      result =
        passthrough
        |> String.split(";")
        |> Enum.map(fn pair ->
          case String.split(pair, ":") do
            [key, val] -> {key, val}
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.into(%{})

      case result do
        %{"type" => type, "project_id" => project_id} = map when type in ["trailer", "film", "live_stream"] ->
          {:ok, map}
        %{"type" => type} when type in ["trailer", "film", "live_stream"] ->
          # Return just the type if project_id is not present (since we get it from external_id now)
          {:ok, %{"type" => type}}
        _ ->
          {:error, :invalid_passthrough}
      end
    rescue
      e ->
        Logger.error("Failed to parse passthrough: #{inspect(e)}")
        {:error, :invalid_passthrough_format}
    end
  end

  defp parse_passthrough_for_type(passthrough) do
    try do
      result =
        passthrough
        |> String.split(";")
        |> Enum.map(fn pair ->
          case String.split(pair, ":") do
            [key, val] -> {key, val}
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.into(%{})

      case result do
        %{"type" => type} when type in ["trailer", "film"] ->
          {:ok, type}
        _ ->
          {:error, :invalid_passthrough}
      end
    rescue
      e ->
        Logger.error("Failed to parse passthrough: #{inspect(e)}")
        {:error, :invalid_passthrough_format}
    end
  end

  defp get_asset_update(type, asset_id) do
    case type do
      "trailer" -> %{trailer_asset_id: asset_id}
      "film" -> %{film_asset_id: asset_id}
      _ -> %{}
    end
  end

  defp find_project_by_asset_id(asset_id) do
    Projects.get_project_by!(trailer_asset_id: asset_id) ||
      Projects.get_project_by!(film_asset_id: asset_id)
  rescue
    e ->
      Logger.error("Error finding project by asset ID: #{inspect(e)}")
      nil
  end

  defp get_playback_update(film, asset_id, playback_id) do
    cond do
      film.trailer_asset_id == asset_id -> %{trailer_playback_id: playback_id}
      film.film_asset_id == asset_id -> %{film_playback_id: playback_id}
      true -> %{}
    end
  end

  def handle_asset_ready_with_project_id(asset_id, playback_id, project_id, type, update_duration \\ true) do
    try do
      with project when not is_nil(project) <- Projects.get_project_with_film!(project_id),
           film <- project.film || Projects.get_or_create_film(project),
           update when update != %{} <- get_asset_and_playback_update_by_type(type, asset_id, playback_id),
           {:ok, updated_film} <- Projects.update_film(film, update) do
        Logger.info("Successfully updated film with asset_id and playback_id for project #{project_id}")

        # If this is a film asset, also update the duration
        if type == "film" and update_duration do
          update_film_duration(updated_film, asset_id)
        end

        :ok
      else
        nil ->
          Logger.error("No project found for project_id: #{project_id}")
          {:error, :project_not_found}
        %{} ->
          Logger.error("Invalid type #{type} for asset update")
          {:error, :invalid_type}
        {:error, reason} ->
          Logger.error("Failed to update film with asset_id and playback_id: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error processing asset ready with project_id: #{inspect(e)}")
        {:error, :unexpected_error}
    end
  end

  defp get_asset_and_playback_update_by_type(type, asset_id, playback_id) do
    case type do
      "trailer" -> %{trailer_asset_id: asset_id, trailer_playback_id: playback_id}
      "film" -> %{film_asset_id: asset_id, film_playback_id: playback_id}
      _ -> %{}
    end
  end

  defp handle_asset_ready_fallback(asset_id, playback_id) do
    try do
      with project when not is_nil(project) <- find_project_by_asset_id(asset_id),
           film <- project.film || Projects.get_or_create_film(project),
           update when update != %{} <- get_playback_update(film, asset_id, playback_id),
           {:ok, _film} <- Projects.update_film(film, update) do
        :ok
      else
        nil ->
          Logger.error("No project found for asset_id: #{asset_id}")
          {:error, :project_not_found}
        %{} ->
          Logger.error("Asset ID #{asset_id} doesn't match project's assets")
          {:error, :asset_mismatch}
        {:error, reason} ->
          Logger.error("Failed to update film with playback ID: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error processing asset ready event: #{inspect(e)}")
        {:error, :unexpected_error}
    end
  end

  defp get_playback_update_by_type(type, playback_id) do
    case type do
      "trailer" -> %{trailer_playback_id: playback_id}
      "film" -> %{film_playback_id: playback_id}
      _ -> %{}
    end
  end

  defp update_film_duration(film, asset_id) do
    try do
      client = Mux.Base.new(System.get_env("MUX_TOKEN_ID"), System.get_env("MUX_SECRET_KEY"))

      case Mux.Video.Assets.get(client, asset_id) do
        {:ok, asset, _tesla_env} ->
          duration = asset["duration"]
          rounded_duration = if duration, do: Float.ceil(duration), else: nil

          if rounded_duration do
            case Projects.update_film(film, %{duration: round(rounded_duration)}) do
              {:ok, _updated_film} ->
                Logger.info("Successfully updated film duration to #{round(rounded_duration)} minutes")
                :ok
              {:error, reason} ->
                Logger.error("Failed to update film duration: #{inspect(reason)}")
                {:error, reason}
            end
          else
            Logger.warning("Duration not found in asset response for asset_id: #{asset_id}")
            :ok
          end

        {:error, reason} ->
          Logger.error("Failed to fetch asset from Mux: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error updating film duration: #{inspect(e)}")
        {:error, :unexpected_error}
    end
  end
end
