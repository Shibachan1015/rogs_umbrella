defmodule Shinkanki.Repo do
  use Ecto.Repo,
    otp_app: :shinkanki,
    adapter: Ecto.Adapters.Postgres
end
