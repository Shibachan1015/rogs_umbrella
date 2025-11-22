defmodule RogsIdentity.Repo do
  use Ecto.Repo,
    otp_app: :rogs_identity,
    adapter: Ecto.Adapters.Postgres
end
