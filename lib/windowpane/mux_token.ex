defmodule Windowpane.MuxToken do
  use Joken.Config

  def generate_playback_token(playback_id, ttl_seconds \\ 86400) do
    private_key_pem =
      System.get_env("MUX_SIGNING_KEY_PRIVATE_KEY")
      |> String.replace("\\n", "\n")

    key_id = System.get_env("MUX_SIGNING_KEY_ID")

    signer =
      Joken.Signer.create(
        "RS256",
        %{"pem" => private_key_pem},
        %{"kid" => key_id}
      )

    exp_time = DateTime.utc_now() |> DateTime.add(ttl_seconds, :second) |> DateTime.to_unix()

    claims = %{
      "sub" => playback_id,
      "exp" => exp_time,
      "aud" => "v",
      "kid" => key_id
    }

    try do
      {:ok, token, _claims} = Joken.encode_and_sign(claims, signer)
      IO.inspect(playback_id, label: "Playback ID")
      IO.inspect(token, label: "Generated JWT token")
      token
    rescue
      error ->
        IO.inspect(error, label: "Joken error")
        reraise error, __STACKTRACE__
    end
  end
end
