defmodule Sokochat.Storage.Images do
  @moduledoc """
  Stores product images.

  `:local` copies into `priv/static` and returns a site path. `:s3` talks to
  MinIO (or any S3 API) with path-style requests signed as AWS SigV4. The
  bucket is created on first use and opened for anonymous reads so an image
  tag and a later WhatsApp fetch can both load the file.
  """

  def put_file(path, key, content_type) when is_binary(path) and is_binary(key) do
    body = File.read!(path)
    put(key, body, content_type || "application/octet-stream")
  end

  def put(key, body, content_type) do
    case config() do
      {:local, root} -> put_local(root, key, body)
      {:s3, settings} -> put_s3(settings, key, body, content_type)
    end
  end

  defp put_local(root, key, body) do
    destination = Path.join(root, Path.join("uploads", key))
    File.mkdir_p!(Path.dirname(destination))
    File.write!(destination, body)
    {:ok, "/uploads/" <> key}
  end

  defp put_s3(settings, key, body, content_type) do
    with :ok <- ensure_bucket(settings),
         :ok <-
           request(settings, :put, object_path(settings, key), body, [
             {"content-type", content_type}
           ]) do
      {:ok, public_url(settings, key)}
    end
  end

  defp ensure_bucket(settings) do
    case :persistent_term.get({__MODULE__, settings.bucket}, :missing) do
      :ready ->
        :ok

      :missing ->
        with :ok <- request(settings, :put, "/" <> settings.bucket, "", []),
             :ok <- put_public_policy(settings) do
          :persistent_term.put({__MODULE__, settings.bucket}, :ready)
          :ok
        end
    end
  end

  defp put_public_policy(settings) do
    policy =
      Jason.encode!(%{
        "Version" => "2012-10-17",
        "Statement" => [
          %{
            "Effect" => "Allow",
            "Principal" => %{"AWS" => ["*"]},
            "Action" => ["s3:GetObject"],
            "Resource" => ["arn:aws:s3:::#{settings.bucket}/*"]
          }
        ]
      })

    request(settings, :put, "/" <> settings.bucket <> "?policy", policy, [
      {"content-type", "application/json"}
    ])
  end

  defp request(settings, method, path, body, extra_headers) do
    now = DateTime.utc_now()
    amz_date = Calendar.strftime(now, "%Y%m%dT%H%M%SZ")
    date = Calendar.strftime(now, "%Y%m%d")
    payload_hash = hex(:crypto.hash(:sha256, body))
    host = host_header(settings)

    headers =
      ([{"host", host}, {"x-amz-content-sha256", payload_hash}, {"x-amz-date", amz_date}] ++
         extra_headers)
      |> Enum.sort_by(&elem(&1, 0))

    canonical_headers = Enum.map_join(headers, "", fn {key, value} -> "#{key}:#{value}\n" end)
    signed_headers = Enum.map_join(headers, ";", &elem(&1, 0))
    {canonical_uri, canonical_query} = split_path(path)

    canonical_request =
      Enum.join(
        [
          method |> Atom.to_string() |> String.upcase(),
          canonical_uri,
          canonical_query,
          canonical_headers,
          signed_headers,
          payload_hash
        ],
        "\n"
      )

    scope = "#{date}/#{settings.region}/s3/aws4_request"

    string_to_sign =
      Enum.join(
        ["AWS4-HMAC-SHA256", amz_date, scope, hex(:crypto.hash(:sha256, canonical_request))],
        "\n"
      )

    signature =
      ("AWS4" <> settings.secret_access_key)
      |> hmac(date)
      |> hmac(settings.region)
      |> hmac("s3")
      |> hmac("aws4_request")
      |> hmac(string_to_sign)
      |> hex()

    authorization =
      "AWS4-HMAC-SHA256 Credential=#{settings.access_key_id}/#{scope}, SignedHeaders=#{signed_headers}, Signature=#{signature}"

    url = settings.scheme <> "://" <> host <> path

    request_headers =
      headers
      |> Enum.reject(fn {key, _} -> key == "host" end)
      |> Kernel.++([{"authorization", authorization}])

    case Finch.request(Finch.build(method, url, request_headers, body), Sokochat.Finch) do
      {:ok, %{status: status}} when status in 200..299 or status == 409 ->
        :ok

      {:ok, %{status: status, body: response_body}} ->
        {:error, "image storage returned HTTP #{status}: #{truncate(response_body)}"}

      {:error, reason} ->
        {:error,
         "image storage is unreachable (#{inspect(reason)}). Start it with docker compose -f compose.minio.yml up -d"}
    end
  rescue
    error ->
      {:error, Exception.message(error)}
  end

  defp split_path(path) do
    case String.split(path, "?", parts: 2) do
      [uri, query] -> {uri, query}
      [uri] -> {uri, ""}
    end
  end

  defp object_path(settings, key), do: "/" <> settings.bucket <> "/" <> key
  defp public_url(settings, key), do: settings.public_base_url <> "/" <> key

  defp host_header(%{host: host, port: port, scheme: "https"}) when port in [nil, 443], do: host
  defp host_header(%{host: host, port: port, scheme: "http"}) when port in [nil, 80], do: host
  defp host_header(%{host: host, port: port}), do: "#{host}:#{port}"

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)
  defp hex(binary), do: Base.encode16(binary, case: :lower)
  defp truncate(body) when is_binary(body), do: String.slice(body, 0, 180)
  defp truncate(body), do: inspect(body)

  defp config do
    settings = Application.get_env(:sokochat, __MODULE__, [])

    case Keyword.get(settings, :adapter, :local) do
      :local ->
        {:local,
         Keyword.get(settings, :local_root, Application.app_dir(:sokochat, "priv/static"))}

      :s3 ->
        {:s3,
         %{
           bucket: Keyword.fetch!(settings, :bucket),
           access_key_id: Keyword.fetch!(settings, :access_key_id),
           secret_access_key: Keyword.fetch!(settings, :secret_access_key),
           scheme: Keyword.get(settings, :scheme, "http"),
           host: Keyword.fetch!(settings, :host),
           port: Keyword.get(settings, :port, 9000),
           region: Keyword.get(settings, :region, "us-east-1"),
           public_base_url: Keyword.fetch!(settings, :public_base_url)
         }}
    end
  end
end
