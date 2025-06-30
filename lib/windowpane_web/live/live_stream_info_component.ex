defmodule WindowpaneWeb.LiveStreamInfoComponent do
  use WindowpaneWeb, :live_component

  alias Windowpane.MuxToken

  def render(assigns) do
    # Generate playback token for the live stream
    playback_token = if assigns.project.live_stream && assigns.project.live_stream.playback_id do
      MuxToken.generate_playback_token(assigns.project.live_stream.playback_id)
    else
      nil
    end

    assigns = assign(assigns, :playback_token, playback_token)

    ~H"""
    <div class="space-y-6">
      <!-- Stream Details Section -->
      <div class="bg-white shadow rounded-lg p-6">
        <div class="space-y-6">
          <!-- Header -->
          <div class="border-b pb-4">
            <h2 class="text-xl font-semibold text-gray-900">Stream Information</h2>
            <p class="mt-1 text-sm text-gray-500">This live stream has been published and is ready for viewing.</p>
          </div>

          <!-- Stream Details -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h3 class="text-lg font-medium text-gray-900 mb-2">Stream Details</h3>
              <dl class="space-y-3">
                <div>
                  <dt class="text-sm font-medium text-gray-500">Title</dt>
                  <dd class="mt-1 text-sm text-gray-900"><%= @project.title %></dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Status</dt>
                  <dd class="mt-1">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      Published
                    </span>
                  </dd>
                </div>
                <%= if @project.premiere_date do %>
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Premiere Date</dt>
                    <dd class="mt-1 text-sm text-gray-900">
                      <%= Calendar.strftime(@project.premiere_date, "%B %d, %Y at %I:%M %p") %>
                    </dd>
                  </div>
                <% end %>
              </dl>
            </div>

            <!-- Stream Configuration -->
            <div>
              <h3 class="text-lg font-medium text-gray-900 mb-2">Broadcasting</h3>
              <%= if @project.live_stream do %>
                <dl class="space-y-3">
                  <%= if @project.live_stream.stream_key do %>
                    <div>
                      <dt class="text-sm font-medium text-gray-500">Stream Key</dt>
                      <dd class="mt-1">
                        <div class="bg-yellow-50 border border-yellow-200 rounded-md p-3">
                          <div class="flex">
                            <div class="flex-shrink-0">
                              <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                                <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                              </svg>
                            </div>
                            <div class="ml-3">
                              <h3 class="text-sm font-medium text-yellow-800">
                                Keep this private!
                              </h3>
                              <div class="mt-2 text-sm text-yellow-700">
                                <p>Do not share your stream key publicly. Anyone with this key can broadcast to your stream.</p>
                              </div>
                            </div>
                          </div>
                          <div class="mt-3">
                            <code class="text-sm text-gray-900 bg-white px-2 py-1 border rounded break-all">
                              <%= @project.live_stream.stream_key %>
                            </code>
                          </div>
                        </div>
                      </dd>
                    </div>
                  <% end %>

                  <%= if @project.live_stream.expected_duration_minutes do %>
                    <div>
                      <dt class="text-sm font-medium text-gray-500">Expected Duration</dt>
                      <dd class="mt-1 text-sm text-gray-900">
                        <%= @project.live_stream.expected_duration_minutes %> minutes
                      </dd>
                    </div>
                  <% end %>
                </dl>
              <% end %>
            </div>
          </div>

          <!-- Additional Information -->
          <div class="border-t pt-4 mt-6">
            <h3 class="text-lg font-medium text-gray-900 mb-2">Additional Information</h3>
            <div class="prose prose-sm max-w-none text-gray-500">
              <%= if @project.description do %>
                <p><%= @project.description %></p>
              <% else %>
                <p class="italic">No additional information provided.</p>
              <% end %>
            </div>
          </div>
        </div>
      </div>
      <!-- Live Player Section -->
      <div class="bg-white shadow rounded-lg overflow-hidden">
        <!-- Player Header -->
        <div class="bg-gray-50 px-6 py-4 border-b">
          <h2 class="text-xl font-semibold text-gray-900">Live Player + Stats</h2>
        </div>

        <!-- Player Content -->
        <div class="p-6">
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <!-- Main Player Area -->
            <div class="lg:col-span-2">
              <div class="aspect-video bg-black rounded-lg overflow-hidden relative">
                <%= if @project.live_stream && @project.live_stream.playback_id && @playback_token do %>
                  <!-- Mux Player -->
                  <script src="https://cdn.jsdelivr.net/npm/@mux/mux-player" defer></script>
                  <mux-player
                    playback-id={@project.live_stream.playback_id}
                    playback-token={@playback_token}
                    metadata-video-title={@project.title}
                    accent-color="#EF4444"
                    stream-type="live"
                    class="w-full h-full"
                  >
                  </mux-player>
                <% else %>
                  <!-- Placeholder when no playback ID -->
                  <div class="flex items-center justify-center h-full">
                    <div class="text-center text-white">
                      <svg class="w-16 h-16 mx-auto mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                      </svg>
                      <p class="text-lg text-gray-300">Stream not available</p>
                      <p class="text-sm text-gray-400">Playback will begin when stream goes live</p>
                    </div>
                  </div>
                <% end %>
              </div>

              <!-- HLS Playback URL Info -->
              <%= if @project.live_stream && @project.live_stream.playback_id do %>
                <div class="mt-4 p-3 bg-gray-50 rounded-lg">
                  <h4 class="text-sm font-medium text-gray-700 mb-2">HLS Playback URL</h4>
                  <code class="text-xs text-gray-600 break-all">
                    https://stream.mux.com/<%= @project.live_stream.playback_id %>.m3u8?token=<%= @playback_token %>
                  </code>
                </div>
              <% end %>
            </div>

            <!-- Side Panel Stats -->
            <div class="lg:col-span-1">
              <div class="bg-gray-50 rounded-lg p-4">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Stream Stats</h3>

                <div class="space-y-4">
                  <!-- Stream Status -->
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Stream Status</dt>
                    <dd class="mt-1">
                      <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{get_status_color(@project.live_stream.status)}"}>
                        <div class={"w-1.5 h-1.5 rounded-full mr-1.5 #{get_status_dot_color(@project.live_stream.status)}"}></div>
                        <%= String.capitalize(@project.live_stream.status) %>
                      </span>
                    </dd>
                  </div>

                  <!-- Viewer Count -->
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Current Viewers</dt>
                    <dd class="mt-1 text-2xl font-bold text-gray-900">
                      <span id="viewer-count">1,247</span>
                      <span class="text-sm font-normal text-green-600 ml-2">↗ +23</span>
                    </dd>
                  </div>

                  <!-- Bitrate & Resolution -->
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Video Quality</dt>
                    <dd class="mt-1 text-sm text-gray-900">
                      <div class="flex items-center space-x-2">
                        <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-blue-100 text-blue-800">
                          1080p
                        </span>
                        <span class="text-gray-500">•</span>
                        <span>4.2 Mbps</span>
                      </div>
                    </dd>
                  </div>

                  <!-- Elapsed Time / Time Remaining -->
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Timing</dt>
                    <dd class="mt-1 text-sm text-gray-900">
                      <div class="space-y-1">
                        <div class="flex justify-between">
                          <span>Elapsed:</span>
                          <span class="font-mono" id="elapsed-time">1:32:15</span>
                        </div>
                        <%= if @project.live_stream.expected_duration_minutes do %>
                          <div class="flex justify-between">
                            <span>Remaining:</span>
                            <span class="font-mono" id="remaining-time">0:27:45</span>
                          </div>
                          <!-- Progress Bar -->
                          <div class="w-full bg-gray-200 rounded-full h-2 mt-2">
                            <div class="bg-red-500 h-2 rounded-full" style="width: 77%"></div>
                          </div>
                        <% end %>
                      </div>
                    </dd>
                  </div>

                  <!-- Peak Viewers -->
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Peak Viewers</dt>
                    <dd class="mt-1 text-lg font-semibold text-gray-900">2,891</dd>
                  </div>

                  <!-- Recording Status -->
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Recording</dt>
                    <dd class="mt-1">
                      <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{if @project.live_stream.recording, do: "bg-red-100 text-red-800", else: "bg-gray-100 text-gray-800"}"}>
                        <%= if @project.live_stream.recording do %>
                          <div class="w-1.5 h-1.5 bg-red-500 rounded-full mr-1.5 animate-pulse"></div>
                          Recording
                        <% else %>
                          Not Recording
                        <% end %>
                      </span>
                    </dd>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for status styling
  defp get_status_color("active"), do: "bg-green-100 text-green-800"
  defp get_status_color("idle"), do: "bg-yellow-100 text-yellow-800"
  defp get_status_color(_), do: "bg-gray-100 text-gray-800"

  defp get_status_dot_color("active"), do: "bg-green-500"
  defp get_status_dot_color("idle"), do: "bg-yellow-500"
  defp get_status_dot_color(_), do: "bg-gray-500"
end
