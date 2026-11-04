defmodule Sokochat.Meta.SharedLine do
  use Ecto.Schema
  import Ecto.Changeset

  alias Sokochat.Accounts.User
  alias Sokochat.Workspaces.Workspace

  @statuses ~w(pending active error)

  schema "shared_lines" do
    belongs_to :account, User, foreign_key: :account_id

    field :phone_number_id, :string
    field :waba_id, :string
    field :access_token, Sokochat.Encrypted.String, source: :access_token_encrypted
    field :verify_token, :string
    field :display_phone, :string
    field :webhook_verified_at, :utc_datetime
    field :status, :string, default: "pending"
    field :last_error, :string

    has_many :workspaces, Workspace

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for the shared-line credentials form. Generates a verify_token on
  first save and resets status to pending whenever credentials change.
  """
  def credentials_changeset(shared_line, attrs) do
    shared_line
    |> cast(attrs, [
      :account_id,
      :phone_number_id,
      :waba_id,
      :access_token,
      :display_phone
    ])
    |> normalize_credential_fields()
    |> put_default_verify_token()
    |> put_change(:status, "pending")
    |> put_change(:last_error, nil)
    |> validate_required([
      :account_id,
      :phone_number_id,
      :waba_id,
      :access_token,
      :display_phone
    ])
    |> validate_length(:phone_number_id, max: 100)
    |> validate_length(:waba_id, max: 100)
    |> validate_length(:access_token, max: 1000)
    |> validate_length(:display_phone, min: 8, max: 15)
    |> validate_format(:display_phone, ~r/\A\d{8,15}\z/,
      message: "must be an E.164 phone number (digits only)"
    )
    |> foreign_key_constraint(:account_id)
    |> unique_constraint(:account_id)
  end

  def status_changeset(shared_line, attrs) do
    shared_line
    |> cast(attrs, [:status, :webhook_verified_at, :last_error, :verify_token])
    |> validate_inclusion(:status, @statuses)
  end

  def statuses, do: @statuses

  defp normalize_credential_fields(changeset) do
    Enum.reduce(
      [:phone_number_id, :waba_id, :access_token, :display_phone],
      changeset,
      fn field, acc ->
        update_change(acc, field, &normalize_string/1)
      end
    )
    |> update_change(:display_phone, &digits_only/1)
  end

  defp normalize_string(value) when is_binary(value) do
    value
    |> String.trim()
    |> strip_wrapping_quotes()
  end

  defp normalize_string(value), do: value

  defp strip_wrapping_quotes("\"" <> rest), do: String.trim_trailing(rest, "\"")
  defp strip_wrapping_quotes("'" <> rest), do: String.trim_trailing(rest, "'")
  defp strip_wrapping_quotes(value), do: value

  defp digits_only(value) when is_binary(value), do: String.replace(value, ~r/\D/, "")
  defp digits_only(value), do: value

  defp put_default_verify_token(changeset) do
    case get_field(changeset, :verify_token) do
      value when is_binary(value) and value != "" -> changeset
      _ -> put_change(changeset, :verify_token, Ecto.UUID.generate())
    end
  end
end
