defmodule Sokochat.Mailer.UnconfiguredAdapter do
  @moduledoc "Returns an explicit delivery error until a production email provider is configured."
  use Swoosh.Adapter

  @impl true
  def deliver(_email, _config), do: {:error, :not_configured}
end
