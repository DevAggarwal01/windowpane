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

  defp handle_event("video.upload.asset_created", %{"data" => %{"id" => asset_id, "passthrough" => passthrough}}) do
    with {:ok, %{"type" => type, "project_id" => project_id}} <- parse_passthrough(passthrough),
         project when not is_nil(project) <- Projects.get_project!(project_id),
         film <- Projects.get_or_create_film(project),
         update <- get_asset_update(type, asset_id),
         {:ok, _film} <- Projects.update_film(film, update) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to process asset creation: #{inspect(reason)}")
        {:error, reason}
      nil ->
        Logger.error("Project not found for passthrough: #{inspect(passthrough)}")
        {:error, :project_not_found}
      error ->
        Logger.error("Unexpected error processing asset creation: #{inspect(error)}")
        {:error, :unexpected_error}
    end
  end

  defp handle_event("video.asset.ready", %{"data" => %{"id" => asset_id, "playback_ids" => [%{"id" => playback_id} | _]}}) do
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
        %{"type" => type, "project_id" => project_id} = map when type in ["trailer", "film"] ->
          {:ok, map}
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
end
