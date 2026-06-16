defmodule Sokochat.Catalogs.Field do
  use Ecto.Schema
  import Ecto.Changeset

  alias Sokochat.Catalogs.Catalog

  @field_types ~w(text textarea number url image_url boolean json)

  schema "catalog_fields" do
    belongs_to :catalog, Catalog

    field :key, :string
    field :label, :string
    field :field_type, :string, default: "text"
    field :required, :boolean, default: false
    field :help_text, :string
    field :position, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(field, attrs) do
    field
    |> cast(attrs, [:catalog_id, :key, :label, :field_type, :required, :help_text, :position])
    |> normalize_string_fields([:key, :label, :field_type, :help_text])
    |> validate_required([:catalog_id, :key, :label, :field_type])
    |> validate_length(:key, min: 1, max: 80)
    |> validate_length(:label, min: 1, max: 120)
    |> validate_format(:key, ~r/^[a-z][a-z0-9_]*$/, message: "must use lowercase snake_case")
    |> validate_inclusion(:field_type, @field_types)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:catalog_id)
    |> unique_constraint([:catalog_id, :key])
  end

  def field_types, do: @field_types

  defp normalize_string_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      update_change(acc, field, &normalize_string/1)
    end)
  end

  defp normalize_string(value) when is_binary(value), do: String.trim(value)
  defp normalize_string(value), do: value
end
