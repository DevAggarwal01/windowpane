defmodule Windowpane.Repo do
  use Ecto.Repo,
    otp_app: :windowpane,
    adapter: Ecto.Adapters.Postgres
end
