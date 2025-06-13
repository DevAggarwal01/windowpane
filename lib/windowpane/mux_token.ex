defmodule Windowpane.MuxToken do
  use Joken.Config

  def generate_playback_token(playback_id, ttl_seconds \\ 3600) do
    private_key_pem =
      System.get_env("MUX_SIGNING_KEY_PRIVATE_KEY")
      |> String.replace("\\n", "\n")

    key_id = System.get_env("MUX_SIGNING_KEY_ID")

    IO.inspect(String.slice(private_key_pem || "", 0, 50), label: "PEM key first 50 chars")
    IO.inspect(key_id, label: "Key ID")

    signer =
      Joken.Signer.create(
        "RS256",
        %{"pem" => private_key_pem},
        %{"kid" => key_id}
      )

    now = DateTime.utc_now() |> DateTime.to_unix()

    claims = %{
      "sub" => playback_id,
      "exp" => now + ttl_seconds,
      "aud" => "v",
      "kid" => key_id
    }

    try do
      {:ok, token, _claims} = Joken.encode_and_sign(claims, signer)
      IO.inspect(token, label: "Generated JWT token")
      IO.inspect(String.slice(token, 0, 100), label: "JWT token first 100 chars")
      token
    rescue
      error ->
        IO.inspect(error, label: "Joken error")
        reraise error, __STACKTRACE__
    end
  end
end
