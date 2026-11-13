defmodule Sokochat.Workspaces.Workspace do
  use Ecto.Schema
  import Ecto.Changeset

  alias Sokochat.Accounts.User
  alias Sokochat.Meta.SharedLine

  schema "workspaces" do
    belongs_to :account, User, foreign_key: :account_id
    belongs_to :shared_line, SharedLine

    field :name, :string
    field :language, :string
    field :slug, :string
    field :ai_instructions, :string
    field :data_source, :string, default: "manual"
    field :company_name, :string
    field :industry, :string
    field :location, :string
    field :phone_number, :string
    field :about, :string
    field :logo_url, :string
    field :website_url, :string
    field :shop_code, :string
    field :marketplace, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [
      :account_id,
      :name,
      :slug,
      :ai_instructions,
      :language,
      :data_source,
      :company_name,
      :industry,
      :location,
      :phone_number,
      :about,
      :logo_url,
      :website_url,
      :shared_line_id,
      :shop_code
    ])
    |> validate_required([:account_id, :name, :slug, :language])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:ai_instructions, max: 5000)
    |> validate_length(:about, max: 2000)
    |> validate_length(:logo_url, max: 2000)
    |> update_change(:website_url, &blank_to_nil/1)
    |> validate_length(:website_url, max: 500)
    |> validate_website_url()
    |> validate_length(:shop_code, max: 64)
    |> validate_format(:shop_code, ~r/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
      message: "must be lowercase letters, numbers, and hyphens"
    )
    |> validate_inclusion(:language, ~w(en sw both))
    |> validate_inclusion(:data_source, ~w(manual api))
    |> maybe_require_shop_code()
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:shared_line_id)
    |> unique_constraint(:slug, name: :workspaces_account_id_slug_index)
    |> unique_constraint([:shared_line_id, :shop_code])
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp validate_website_url(changeset) do
    validate_change(changeset, :website_url, fn :website_url, url ->
      case URI.parse(url) do
        %URI{scheme: scheme, host: host}
        when scheme in ["http", "https"] and is_binary(host) and host != "" ->
          []

        _ ->
          [website_url: "must start with https://"]
      end
    end)
  end

  defp maybe_require_shop_code(changeset) do
    case get_field(changeset, :shared_line_id) do
      nil ->
        changeset
        |> put_change(:shop_code, nil)

      _id ->
        validate_required(changeset, [:shop_code])
    end
  end
end
