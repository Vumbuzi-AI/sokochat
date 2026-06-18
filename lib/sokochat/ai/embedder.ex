defmodule Sokochat.AI.Embedder do
  @moduledoc """
  Turns text into embedding vectors via OpenAI's embeddings API.

  Used to index catalog items and to embed inbound buyer messages for
  semantic retrieval (RAG). Returns plain lists of floats; persistence as a
  pgvector value is handled by `Pgvector.Ecto.Vector` at the schema layer.
  """

  @api_url "https://api.openai.com/v1/embeddings"
  @max_retries 5

  @doc """
  Embeds a single string. Returns `{:ok, [float]}` or `{:error, reason}`.
  """
  def embed(text) when is_binary(text) do
    case embed_many([text]) do
      {:ok, [vector]} -> {:ok, vector}
      {:ok, _other} -> {:error, "unexpected embedding count"}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Embeds a batch of strings in one request, preserving order.
  Returns `{:ok, [[float]]}` or `{:error, reason}`.
  """
  def embed_many([]), do: {:ok, []}

  def embed_many(texts) when is_list(texts) do
    config = Application.fetch_env!(:sokochat, :embeddings)

    payload = %{
      model: Keyword.fetch!(config, :model),
      input: Enum.map(texts, &normalize_input/1),
      dimensions: Keyword.fetch!(config, :dimensions)
    }

    with {:ok, response} <- Req.post(request_options(config, payload)),
         {:ok, body} <- parse_response(response) do
      extract_vectors(body)
    end
  end

  defp request_options(config, payload) do
    default_options =
      Process.get(:openai_req_options) ||
        Application.get_env(:sokochat, :openai_req_options, [])

    default_options
    |> Keyword.merge(
      url: @api_url,
      max_retries: @max_retries,
      headers: [
        {"authorization", "Bearer #{Keyword.fetch!(config, :api_key)}"},
        {"content-type", "application/json"}
      ],
      json: payload
    )
  end

  # The API rejects empty strings; fall back to a single space.
  defp normalize_input(text) when is_binary(text) do
    case String.trim(text) do
      "" -> " "
      trimmed -> trimmed
    end
  end

  defp parse_response(%Req.Response{status: status, body: body}) when status in 200..299,
    do: {:ok, body}

  defp parse_response(%Req.Response{status: status, body: body}) do
    {:error, "embeddings API error (HTTP #{status}): #{error_message(body)}"}
  end

  defp extract_vectors(%{"data" => data}) when is_list(data) do
    vectors =
      data
      |> Enum.sort_by(&Map.get(&1, "index", 0))
      |> Enum.map(&Map.get(&1, "embedding"))

    if Enum.all?(vectors, &is_list/1) do
      {:ok, vectors}
    else
      {:error, "embeddings response missing vectors"}
    end
  end

  defp extract_vectors(_body), do: {:error, "unexpected embeddings response"}

  defp error_message(body) when is_binary(body), do: body

  defp error_message(body) when is_map(body),
    do: get_in(body, ["error", "message"]) || "request failed"

  defp error_message(_body), do: "request failed"
end
