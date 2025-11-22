defmodule RogsComm.Repo do
  use Ecto.Repo,
    otp_app: :rogs_comm,
    adapter: Ecto.Adapters.Postgres
end
