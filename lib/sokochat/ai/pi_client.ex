defmodule Sokochat.AI.PiClient do
  @moduledoc """
  Submits or reacquires a durable turn for the PostgreSQL/Oban reconciler.
  The saved user-message ID is the idempotency key. Transport retries therefore
  reacquire the same work rather than starting another model generation.
  """
  def exchange(payload) do
    config = Application.fetch_env!(:sokochat, :intelligence)

    with {:ok, response} <- Req.post(options(config, "/v1/turns") ++ [json: payload]),
         {:ok, result} <- accept(response),
         do: {:ok, result}
  end

  defp options(config, path) do
    [
      url: String.trim_trailing(Keyword.fetch!(config, :pi_url), "/") <> path,
      headers: [{"authorization", "Bearer #{Keyword.fetch!(config, :pi_token)}"}],
      receive_timeout: 10_000,
      connect_options: [timeout: 3000],
      retry: :transient,
      max_retries: 1
    ]
    |> Keyword.merge(Process.get(:pi_req_options, []))
  end

  defp accept(%Req.Response{status: status, body: body})
       when status in [200, 202] and is_map(body),
       do: {:ok, body}

  defp accept(%Req.Response{status: 401}),
    do:
      {:error,
       "Pi service credentials do not match. Check PI_SERVICE_TOKEN and restart both services."}

  defp accept(%Req.Response{status: status}) when status in [429, 503],
    do: {:error, "The intelligence service is busy. Please try again shortly."}

  defp accept(_response), do: {:error, "The Pi service could not accept this turn."}

  def decode_answer(%{"text" => text, "tokens" => tokens})
      when is_binary(text) and is_integer(tokens) and tokens >= 0 do
    with {:ok, %{"reply" => reply, "policy" => policy, "cta" => cta}} <- Jason.decode(text),
         true <-
           is_binary(reply) and byte_size(reply) > 0 and String.length(reply) <= 20_000 and
             policy in ["ok", "refuse"] and (is_nil(cta) or is_map(cta)) do
      {:ok, %{reply: reply, cta: cta, policy: policy, tokens: tokens}}
    else
      _ -> {:error, "The Pi service returned an invalid sales reply."}
    end
  end

  def decode_answer(_answer), do: {:error, "The Pi service returned an incomplete reply."}
end
