defmodule Sokochat.AI.OpenAIClient do
  @moduledoc """
  Thin client for OpenAI's Responses API.
  """

  @api_url "https://api.openai.com/v1/responses"
  @max_retries 10

  def chat(messages, system_prompt) when is_list(messages) and is_binary(system_prompt) do
    openai_config = Application.fetch_env!(:sokochat, :openai)

    request_options =
      request_options(openai_config, %{
        model: Keyword.fetch!(openai_config, :model),
        max_output_tokens: Keyword.fetch!(openai_config, :max_output_tokens),
        instructions: system_prompt,
        input: normalize_messages(messages),
        reasoning: %{effort: Keyword.fetch!(openai_config, :reasoning_effort)},
        text: %{
          verbosity: Keyword.fetch!(openai_config, :text_verbosity),
          format: response_format()
        }
      })

    with {:ok, response} <- Req.post(request_options),
         {:ok, body} <- parse_response(response) do
      build_result(body)
    end
  end

  defp request_options(openai_config, payload) do
    default_options =
      Process.get(:openai_req_options) ||
        Application.get_env(:sokochat, :openai_req_options, [])

    default_options
    |> Keyword.merge(
      url: @api_url,
      max_retries: @max_retries,
      headers: [
        {"authorization", "Bearer #{Keyword.fetch!(openai_config, :api_key)}"},
        {"content-type", "application/json"}
      ],
      json: payload
    )
  end

  defp parse_response(%Req.Response{status: status, body: body}) when status in 200..299,
    do: {:ok, body}

  defp parse_response(%Req.Response{status: status, body: body}) do
    {:error, "OpenAI API error (HTTP #{status}): #{error_message(body)}"}
  end

  defp build_result(body) when is_map(body) do
    text = extract_text(body)

    case Jason.decode(text) do
      {:ok, %{"reply" => reply} = parsed} ->
        {:ok,
         %{
           reply: reply,
           cta: Map.get(parsed, "cta"),
           tokens: token_count(body)
         }}

      {:ok, parsed} when is_map(parsed) ->
        {:ok,
         %{
           reply: Map.get(parsed, "reply", text),
           cta: Map.get(parsed, "cta"),
           tokens: token_count(body)
         }}

      {:error, _reason} ->
        {:ok,
         %{
           reply: text,
           cta: nil,
           tokens: token_count(body)
         }}
    end
  end

  defp extract_text(%{"output_text" => text}) when is_binary(text), do: text

  defp extract_text(%{"output" => output}) when is_list(output) do
    output
    |> Enum.find_value("", &extract_output_item_text/1)
  end

  defp extract_text(%{output: output}) when is_list(output) do
    output
    |> Enum.find_value("", &extract_output_item_text/1)
  end

  defp extract_text(_body), do: ""

  defp extract_output_item_text(%{"content" => content}) when is_list(content) do
    Enum.find_value(content, &extract_content_text/1)
  end

  defp extract_output_item_text(%{content: content}) when is_list(content) do
    Enum.find_value(content, &extract_content_text/1)
  end

  defp extract_output_item_text(_item), do: nil

  defp extract_content_text(%{"type" => "output_text", "text" => text}) when is_binary(text),
    do: text

  defp extract_content_text(%{type: "output_text", text: text}) when is_binary(text), do: text

  defp extract_content_text(%{"type" => "refusal", "refusal" => refusal}) when is_binary(refusal),
    do: refusal

  defp extract_content_text(%{type: "refusal", refusal: refusal}) when is_binary(refusal),
    do: refusal

  defp extract_content_text(_content), do: nil

  defp token_count(%{"usage" => usage}) when is_map(usage) do
    usage
    |> Map.get("total_tokens")
    |> normalize_integer(usage_value(usage, "input_tokens") + usage_value(usage, "output_tokens"))
  end

  defp token_count(%{usage: usage}) when is_map(usage) do
    usage
    |> Map.get(:total_tokens)
    |> normalize_integer(usage_value(usage, :input_tokens) + usage_value(usage, :output_tokens))
  end

  defp token_count(_body), do: 0

  defp usage_value(usage, key), do: usage |> Map.get(key, 0) |> normalize_integer()

  defp normalize_integer(value, _fallback) when is_integer(value), do: value
  defp normalize_integer(_value, fallback), do: fallback

  defp normalize_integer(value) when is_integer(value), do: value
  defp normalize_integer(_value), do: 0

  defp error_message(body) when is_binary(body), do: body

  defp error_message(body) when is_map(body) do
    get_in(body, ["error", "message"]) || Jason.encode!(body)
  end

  defp error_message(_body), do: "request failed"

  defp normalize_messages(messages) do
    Enum.map(messages, fn message ->
      %{
        role: normalize_role(message_field(message, :role)),
        content: message_field(message, :content) || ""
      }
    end)
  end

  defp normalize_role("assistant"), do: "assistant"
  defp normalize_role("user"), do: "user"
  defp normalize_role(:assistant), do: "assistant"
  defp normalize_role(:user), do: "user"
  defp normalize_role(_role), do: "user"

  defp message_field(message, key) when is_map(message) do
    Map.get(message, key) || Map.get(message, Atom.to_string(key))
  end

  defp response_format do
    %{
      type: "json_schema",
      name: "sales_assistant_response",
      strict: true,
      schema: %{
        type: "object",
        additionalProperties: false,
        required: ["reply", "cta"],
        properties: %{
          reply: %{type: "string"},
          cta: %{
            anyOf: [
              %{type: "null"},
              website_cta_schema(),
              phone_cta_schema("phone"),
              phone_cta_schema("whatsapp"),
              reply_buttons_cta_schema(),
              list_message_cta_schema(),
              location_cta_schema(),
              catalog_cta_schema(),
              custom_cta_schema()
            ]
          }
        }
      }
    }
  end

  defp website_cta_schema do
    %{
      type: "object",
      additionalProperties: false,
      required: ["type", "payload"],
      properties: %{
        type: %{type: "string", enum: ["website"]},
        payload:
          payload_schema(
            %{
              url: %{type: "string"}
            },
            ["url"]
          )
      }
    }
  end

  defp phone_cta_schema(type) do
    %{
      type: "object",
      additionalProperties: false,
      required: ["type", "payload"],
      properties: %{
        type: %{type: "string", enum: [type]},
        payload:
          payload_schema(
            %{
              number: %{type: "string"}
            },
            ["number"]
          )
      }
    }
  end

  defp reply_buttons_cta_schema do
    %{
      type: "object",
      additionalProperties: false,
      required: ["type", "payload"],
      properties: %{
        type: %{type: "string", enum: ["reply_buttons"]},
        payload:
          payload_schema(
            %{
              title: %{type: "string"},
              body: %{type: "string"},
              buttons: %{
                type: "array",
                items: %{type: "string"},
                minItems: 1,
                maxItems: 3
              }
            },
            ["buttons"]
          )
      }
    }
  end

  defp list_message_cta_schema do
    %{
      type: "object",
      additionalProperties: false,
      required: ["type", "payload"],
      properties: %{
        type: %{type: "string", enum: ["list_message"]},
        payload:
          payload_schema(
            %{
              title: %{type: "string"},
              body: %{type: "string"},
              items: %{
                type: "array",
                minItems: 1,
                maxItems: 6,
                items: %{
                  type: "object",
                  additionalProperties: false,
                  required: ["title", "description"],
                  properties: %{
                    title: %{type: "string"},
                    description: %{type: "string"}
                  }
                }
              }
            },
            ["items"]
          )
      }
    }
  end

  defp location_cta_schema do
    %{
      type: "object",
      additionalProperties: false,
      required: ["type", "payload"],
      properties: %{
        type: %{type: "string", enum: ["location"]},
        payload:
          payload_schema(
            %{
              latitude: %{type: "number"},
              longitude: %{type: "number"}
            },
            ["latitude", "longitude"]
          )
      }
    }
  end

  defp catalog_cta_schema do
    %{
      type: "object",
      additionalProperties: false,
      required: ["type", "payload"],
      properties: %{
        type: %{type: "string", enum: ["catalog"]},
        payload:
          payload_schema(
            %{
              product_id: %{type: "string"}
            },
            ["product_id"]
          )
      }
    }
  end

  defp custom_cta_schema do
    %{
      type: "object",
      additionalProperties: false,
      required: ["type", "payload"],
      properties: %{
        type: %{type: "string", enum: ["custom"]},
        payload:
          payload_schema(
            %{
              template: %{type: "string"}
            },
            ["template"]
          )
      }
    }
  end

  defp payload_schema(properties, required_fields) do
    preview_properties = %{
      title: nullable_string_schema(),
      body: nullable_string_schema(),
      image_url: nullable_string_schema()
    }

    %{
      type: "object",
      additionalProperties: false,
      required: required_fields ++ Map.keys(preview_properties),
      properties: Map.merge(properties, preview_properties)
    }
  end

  defp nullable_string_schema do
    %{
      anyOf: [
        %{type: "string"},
        %{type: "null"}
      ]
    }
  end
end
