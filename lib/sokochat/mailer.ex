defmodule Sokochat.Mailer do
  use Swoosh.Mailer, otp_app: :sokochat

  require Logger

  def configured? do
    Application.fetch_env!(:sokochat, __MODULE__)[:adapter] !=
      Sokochat.Mailer.UnconfiguredAdapter
  end

  def deliver_safely(email) do
    case deliver(email) do
      {:ok, _} = result -> result
      {:error, _} -> unavailable()
    end
  rescue
    _ -> unavailable()
  catch
    :exit, _ -> unavailable()
  end

  defp unavailable do
    # Provider exceptions may contain reset/confirmation tokens or credentials.
    Logger.warning("Account email delivery unavailable")
    {:error, :delivery_unavailable}
  end
end
