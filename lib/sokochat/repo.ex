defmodule Sokochat.Repo do
  use Ecto.Repo,
    otp_app: :sokochat,
    adapter: Ecto.Adapters.Postgres
end
