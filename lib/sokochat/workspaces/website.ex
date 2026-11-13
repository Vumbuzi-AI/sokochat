defmodule Sokochat.Workspaces.Website do
  @moduledoc """
  Reads a public business website and turns the page into a short brief
  for the workspace AI content.
  """

  @max_bytes 500_000
  @timeout 8_000

  @doc """
  Fetches `url` and returns text Sokochat can store as AI instructions.

  Only public http(s) hosts are requested. Private, loopback and link-local
  addresses are refused.
  """
  def brief(url) when is_binary(url) do
    with {:ok, uri} <- public_uri(url),
         {:ok, html} <- fetch(uri, 3) do
      readable(html)
    end
  end

  def brief(_url), do: {:error, "Use a link starting with https://"}

  defp public_uri(url, base \\ nil)

  defp public_uri(url, base) when is_binary(url) do
    uri = URI.parse(String.trim(url))

    uri =
      if is_nil(uri.scheme) and not is_nil(base) do
        URI.merge(base, uri)
      else
        uri
      end

    cond do
      uri.scheme not in ["http", "https"] or not is_binary(uri.host) or uri.host == "" ->
        {:error, "Use a link starting with https://"}

      uri.userinfo ->
        {:error, "That link is not a public website."}

      not public_host?(uri.host) ->
        {:error, "That link is not a public website."}

      true ->
        {:ok, %{uri | fragment: nil}}
    end
  end

  defp public_uri(_url, _base), do: {:error, "Use a link starting with https://"}

  defp public_host?(host) do
    host = host |> String.trim() |> String.downcase()

    cond do
      test_transport?() ->
        true

      host in ["localhost", "localhost.localdomain"] ->
        false

      String.ends_with?(host, ".local") or String.ends_with?(host, ".internal") ->
        false

      true ->
        case addresses(host) do
          {:ok, ips} -> ips != [] and Enum.all?(ips, &public_ip?/1)
          :error -> false
        end
    end
  end

  defp test_transport? do
    options =
      Process.get(:website_req_options) ||
        Application.get_env(:sokochat, :website_req_options, [])

    Keyword.has_key?(options, :plug)
  end

  defp addresses(host) do
    charlist = String.to_charlist(host)

    case :inet.parse_address(charlist) do
      {:ok, ip} ->
        {:ok, [ip]}

      {:error, _} ->
        lookup(charlist)
    end
  end

  defp lookup(charlist) do
    v4 = :inet.getaddrs(charlist, :inet)
    v6 = :inet.getaddrs(charlist, :inet6)

    case {v4, v6} do
      {{:ok, a}, {:ok, b}} -> {:ok, a ++ b}
      {{:ok, a}, _} -> {:ok, a}
      {_, {:ok, b}} -> {:ok, b}
      _ -> :error
    end
  end

  defp public_ip?({0, 0, 0, 0, 0, 0xFFFF, hi, lo}) do
    public_ip?({div(hi, 256), rem(hi, 256), div(lo, 256), rem(lo, 256)})
  end

  defp public_ip?({0, 0, 0, 0, 0, 0, 0, 0}), do: false
  defp public_ip?({0, 0, 0, 0, 0, 0, 0, 1}), do: false
  defp public_ip?({a, _, _, _, _, _, _, _}) when a >= 0xFC00 and a <= 0xFDFF, do: false
  defp public_ip?({a, _, _, _, _, _, _, _}) when a >= 0xFE80 and a <= 0xFEBF, do: false
  defp public_ip?({_, _, _, _, _, _, _, _}), do: true
  defp public_ip?({0, _, _, _}), do: false
  defp public_ip?({10, _, _, _}), do: false
  defp public_ip?({127, _, _, _}), do: false
  defp public_ip?({169, 254, _, _}), do: false
  defp public_ip?({172, second, _, _}) when second >= 16 and second <= 31, do: false
  defp public_ip?({192, 168, _, _}), do: false
  defp public_ip?({100, second, _, _}) when second >= 64 and second <= 127, do: false
  defp public_ip?({first, _, _, _}) when first >= 224, do: false
  defp public_ip?({_, _, _, _}), do: true

  defp fetch(_uri, 0), do: {:error, "The site did not return a page."}

  defp fetch(%URI{} = uri, hops) do
    case Req.get(request_options(uri)) do
      {:ok, %{status: status} = response} when status in [301, 302, 303, 307, 308] ->
        follow(response, uri, hops)

      {:ok, %{status: status} = response} when status in 200..299 ->
        html_body(response)

      {:ok, %{status: status}} ->
        {:error, "The site returned HTTP #{status}."}

      {:error, _reason} ->
        {:error, "Could not reach the site."}
    end
  end

  defp follow(response, base, hops) do
    case header(response.headers, "location") do
      nil ->
        {:error, "The site did not return a page."}

      location ->
        with {:ok, next} <- public_uri(location, base) do
          fetch(next, hops - 1)
        end
    end
  end

  defp html_body(response) do
    if html?(response) and is_binary(response.body) do
      {:ok, String.slice(response.body, 0, @max_bytes)}
    else
      {:error, "The site did not return a page."}
    end
  end

  defp html?(response) do
    case header(response.headers, "content-type") do
      nil -> true
      type -> String.contains?(String.downcase(type), "html")
    end
  end

  defp request_options(uri) do
    defaults =
      Process.get(:website_req_options) ||
        Application.get_env(:sokochat, :website_req_options, [])

    Keyword.merge(defaults,
      url: URI.to_string(uri),
      redirect: false,
      max_retries: 0,
      receive_timeout: @timeout,
      connect_options: [timeout: 5_000]
    )
  end

  defp header(headers, name) when is_map(headers) do
    value = Map.get(headers, name) || Map.get(headers, String.to_atom(name))

    case value do
      [first | _] -> first
      first when is_binary(first) -> first
      _ -> nil
    end
  end

  defp header(headers, name) when is_list(headers) do
    Enum.find_value(headers, fn
      {key, value} -> if String.downcase(to_string(key)) == name, do: to_string(value)
      _ -> nil
    end)
  end

  defp readable(html) do
    title = text_in(html, "title")
    description = meta(html, "description") || meta(html, "og:description")

    body =
      html
      |> strip(~r/<script\b[^>]*>.*?<\/script>/is)
      |> strip(~r/<style\b[^>]*>.*?<\/style>/is)
      |> strip(~r/<noscript\b[^>]*>.*?<\/noscript>/is)
      |> strip_tags()
      |> decode()
      |> collapse()
      |> String.slice(0, 1_800)

    lines =
      [{"Business", title}, {nil, description}, {nil, body}]
      |> Enum.flat_map(fn
        {_label, value} when value in [nil, ""] -> []
        {nil, value} -> [value]
        {label, value} -> ["#{label}: #{value}"]
      end)

    case lines do
      [] -> {:error, "The site had no text we could use."}
      lines -> {:ok, lines |> Enum.join("\n\n") |> String.slice(0, 4_000)}
    end
  end

  defp text_in(html, tag) do
    case Regex.run(~r/<#{tag}\b[^>]*>(.*?)<\/#{tag}>/is, html) do
      [_, inner] -> inner |> strip_tags() |> decode() |> collapse()
      _ -> nil
    end
  end

  defp meta(html, name) do
    [
      ~r/<meta\b[^>]*name=["']#{name}["'][^>]*content=["']([^"']*)["']/i,
      ~r/<meta\b[^>]*content=["']([^"']*)["'][^>]*name=["']#{name}["']/i,
      ~r/<meta\b[^>]*property=["']#{name}["'][^>]*content=["']([^"']*)["']/i,
      ~r/<meta\b[^>]*content=["']([^"']*)["'][^>]*property=["']#{name}["']/i
    ]
    |> Enum.find_value(fn pattern ->
      case Regex.run(pattern, html) do
        [_, content] -> content |> decode() |> collapse()
        _ -> nil
      end
    end)
  end

  defp strip(html, pattern), do: String.replace(html, pattern, " ")
  defp strip_tags(html), do: String.replace(html, ~r/<[^>]+>/, " ")

  defp decode(text) do
    text
    |> String.replace("&nbsp;", " ")
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&apos;", "'")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
  end

  defp collapse(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
