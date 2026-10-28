defmodule Sokochat.AI.Intelligence do
  @moduledoc """
  Selects the chat runtime while keeping Phoenix's business context, policy,
  persistence, and channel rendering independent of the model harness.
  """
  def agentic? do
    Application.get_env(:sokochat, :intelligence, []) |> Keyword.get(:backend) == "pi"
  end
end
