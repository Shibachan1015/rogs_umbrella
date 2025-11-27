defmodule RogsGame.Repo do
  use Ecto.Repo,
    otp_app: :rogs_game,
    adapter: Ecto.Adapters.Postgres
end
