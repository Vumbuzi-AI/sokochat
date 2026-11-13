defmodule Sokochat.Workspaces.Workspace do
  use Ecto.Schema
  import Ecto.Changeset

  alias Sokochat.Accounts.User
  alias Sokochat.Meta.SharedLine

  schema "workspaces" do
    belongs_to :account, User, foreign_key: :account_id
    belongs_to :shared_line, SharedLine

    field :name, :string
    field :language, :string, default: "both"
    field :slug, :string
    field :ai_instructions, :string
    field :data_source, :string, default: "manual"
    field :company_name, :string
    field :industry, :string
    field :location, :string
    field :pickup_enabled, :boolean, default: false
    field :opening_hours, :string
    field :map_url, :string
    field :delivery_enabled, :boolean, default: false
    field :delivery_quote_outside, :boolean, default: true
    embeds_many :delivery_rates, Sokochat.Workspaces.DeliveryRate, on_replace: :delete
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
      :pickup_enabled,
      :opening_hours,
      :map_url,
      :delivery_enabled,
      :delivery_quote_outside,
      :phone_number,
      :about,
      :logo_url,
      :website_url,
      :shared_line_id,
      :shop_code
    ])
    |> cast_embed(:delivery_rates)
    |> validate_length(:delivery_rates, max: 8)
    |> validate_length(:location, max: 500)
    |> validate_length(:opening_hours, max: 500)
    |> validate_length(:map_url, max: 2000)
    |> validate_change(:map_url, fn :map_url, url ->
      case URI.parse(url) do
        %URI{scheme: scheme, host: host}
        when scheme in ["https", "http"] and is_binary(host) and host != "" ->
          []

        _ ->
          [map_url: "must be an http or https link"]
      end
    end)
    |> validate_fulfillment()
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

  defp validate_fulfillment(changeset) do
    changeset =
      if get_field(changeset, :pickup_enabled),
        do: validate_required(changeset, [:location]),
        else: changeset

    rates = get_field(changeset, :delivery_rates) || []
    areas = Enum.map(rates, &String.downcase(String.trim(&1.area || "")))

    changeset =
      if length(Enum.uniq(areas)) != length(areas),
        do: add_error(changeset, :delivery_rates, "must have different area names"),
        else: changeset

    if get_field(changeset, :delivery_enabled) && rates == [] &&
         !get_field(changeset, :delivery_quote_outside),
       do: add_error(changeset, :delivery_rates, "add an area or accept delivery quotes"),
       else: changeset
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
