defmodule Sokochat.Meta do
  @moduledoc """
  The Meta context. Manages per-workspace WhatsApp Cloud API connections and
  account-level shared lines used by multiple shop workspaces.
  """

  import Ecto.Query, warn: false

  alias Sokochat.Meta.Connection
  alias Sokochat.Meta.SharedLine
  alias Sokochat.Meta.ShopBinding
  alias Sokochat.Repo
  alias Sokochat.Workspaces.Workspace

  ## Connections (dedicated per-workspace number)

  @doc "Returns the workspace's Meta connection, or nil."
  def get_connection(workspace_id) do
    Repo.get_by(Connection, workspace_id: workspace_id)
  end

  @doc "Returns the Meta connection for a workspace slug, preloading the workspace."
  def get_connection_by_workspace_slug(slug) do
    query =
      from connection in Connection,
        join: workspace in assoc(connection, :workspace),
        where: workspace.slug == ^slug,
        preload: [workspace: workspace]

    Repo.one(query)
  end

  @doc "Returns the workspace's connection or an unsaved struct to back a form."
  def get_connection_or_new(workspace_id) do
    get_connection(workspace_id) || %Connection{workspace_id: workspace_id}
  end

  def change_connection(%Connection{} = connection, attrs \\ %{}) do
    Connection.credentials_changeset(connection, attrs)
  end

  @doc """
  Inserts or updates the workspace's connection credentials. The verify_token is
  preserved across updates so an already-configured webhook keeps working.
  """
  def upsert_connection(workspace_id, attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put("workspace_id", workspace_id)

    workspace_id
    |> get_connection_or_new()
    |> Connection.credentials_changeset(attrs)
    |> Repo.insert_or_update()
  end

  @doc "Marks the webhook verified and moves the connection toward active."
  def mark_verified(%Connection{} = connection) do
    update_connection_status(connection, %{
      status: "active",
      webhook_verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
      last_error: nil
    })
  end

  def mark_verified(%SharedLine{} = shared_line) do
    update_shared_line_status(shared_line, %{
      status: "active",
      webhook_verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
      last_error: nil
    })
  end

  @doc "Records an error against the connection or shared line."
  def mark_error(%Connection{} = connection, reason) do
    update_connection_status(connection, %{status: "error", last_error: to_string(reason)})
  end

  def mark_error(%SharedLine{} = shared_line, reason) do
    update_shared_line_status(shared_line, %{status: "error", last_error: to_string(reason)})
  end

  @doc """
  Returns the credentials used to send WhatsApp messages for a workspace.

  Prefer the account shared line when the workspace is a member; otherwise the
  dedicated per-workspace connection.
  """
  def connection_for_send(workspace_id) do
    query =
      from workspace in Workspace,
        where: workspace.id == ^workspace_id,
        left_join: shared_line in assoc(workspace, :shared_line),
        preload: [shared_line: shared_line]

    case Repo.one(query) do
      %Workspace{shared_line: %SharedLine{} = shared_line} -> shared_line
      %Workspace{} -> get_connection(workspace_id)
      nil -> nil
    end
  end

  ## Shared lines

  @doc "Returns the account's shared line, or nil."
  def get_shared_line(account_id) do
    Repo.get_by(SharedLine, account_id: account_id)
  end

  @doc "Returns the account's shared line or an unsaved struct to back a form."
  def get_shared_line_or_new(account_id) do
    get_shared_line(account_id) || %SharedLine{account_id: account_id}
  end

  @doc "Looks up a shared line by its webhook verify token."
  def get_shared_line_by_verify_token(token) when is_binary(token) do
    Repo.get_by(SharedLine, verify_token: token)
  end

  def get_shared_line_by_verify_token(_), do: nil

  @doc "Looks up a shared line by Meta phone number id."
  def get_shared_line_by_phone_number_id(phone_number_id) when is_binary(phone_number_id) do
    Repo.get_by(SharedLine, phone_number_id: phone_number_id)
  end

  def get_shared_line_by_phone_number_id(_), do: nil

  @doc """
  Returns the shared line for an inbound webhook. Prefers a match on
  `phone_number_id`; falls back to the sole configured shared line.
  """
  def resolve_shared_line_for_inbound(phone_number_id) do
    case get_shared_line_by_phone_number_id(phone_number_id) do
      %SharedLine{} = line ->
        line

      nil ->
        case Repo.all(from line in SharedLine, limit: 2) do
          [line] -> line
          _ -> nil
        end
    end
  end

  def change_shared_line(%SharedLine{} = shared_line, attrs \\ %{}) do
    SharedLine.credentials_changeset(shared_line, attrs)
  end

  @doc """
  Inserts or updates the account's shared-line credentials. The verify_token is
  preserved across updates so an already-configured webhook keeps working.
  """
  def upsert_shared_line(account_id, attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put("account_id", account_id)

    account_id
    |> get_shared_line_or_new()
    |> SharedLine.credentials_changeset(attrs)
    |> Repo.insert_or_update()
  end

  @doc "Lists workspaces that are members of the shared line."
  def list_shared_line_shops(shared_line_id) do
    Workspace
    |> where(
      [workspace],
      workspace.shared_line_id == ^shared_line_id and not workspace.marketplace
    )
    |> order_by([workspace], asc: workspace.name)
    |> Repo.all()
  end

  @doc "Finds a shop workspace on the shared line by its shop_code."
  def get_shop_by_code(shared_line_id, shop_code) when is_binary(shop_code) do
    code = shop_code |> String.trim() |> String.downcase()

    Repo.get_by(Workspace, shared_line_id: shared_line_id, shop_code: code)
  end

  def get_shop_by_code(_shared_line_id, _shop_code), do: nil

  @doc "Attaches a workspace to the account shared line with the given shop code."
  def join_shared_line(%Workspace{} = workspace, %SharedLine{} = shared_line, shop_code \\ nil) do
    code =
      (shop_code || workspace.shop_code || workspace.slug)
      |> to_string()
      |> String.trim()
      |> String.downcase()

    workspace
    |> Workspace.changeset(%{
      "shared_line_id" => shared_line.id,
      "shop_code" => code
    })
    |> Repo.update()
  end

  @doc "Removes a workspace from the shared line."
  def leave_shared_line(%Workspace{} = workspace) do
    workspace
    |> Workspace.changeset(%{"shared_line_id" => nil, "shop_code" => nil})
    |> Repo.update()
  end

  @doc "Builds the click-to-chat URL with a prefilled shop token."
  def shop_wa_me_url(%SharedLine{display_phone: phone}, %Workspace{} = workspace)
      when is_binary(phone) and phone != "" do
    code = workspace.shop_code || workspace.slug
    name = workspace.name || code

    text =
      "What do you have at #{name}? [shop:#{code}]"
      |> URI.encode_www_form()

    "https://wa.me/#{digits_only(phone)}?text=#{text}"
  end

  def shop_wa_me_url(_shared_line, _workspace), do: nil

  ## Shop bindings

  def get_shop_binding(shared_line_id, phone_number) do
    Repo.get_by(ShopBinding,
      shared_line_id: shared_line_id,
      phone_number: phone_number
    )
  end

  def get_shop_binding_with_workspace(shared_line_id, phone_number) do
    query =
      from binding in ShopBinding,
        where:
          binding.shared_line_id == ^shared_line_id and binding.phone_number == ^phone_number,
        preload: [:workspace]

    Repo.one(query)
  end

  @doc "Creates or updates the buyer's shop binding on the shared line."
  def upsert_shop_binding(shared_line_id, phone_number, workspace_id) do
    attrs = %{
      "shared_line_id" => shared_line_id,
      "phone_number" => phone_number,
      "workspace_id" => workspace_id
    }

    case get_shop_binding(shared_line_id, phone_number) do
      nil ->
        %ShopBinding{}
        |> ShopBinding.changeset(attrs)
        |> Repo.insert()

      %ShopBinding{} = binding ->
        binding
        |> ShopBinding.changeset(attrs)
        |> Repo.update()
    end
  end

  defp update_connection_status(%Connection{} = connection, attrs) do
    connection
    |> Connection.status_changeset(attrs)
    |> Repo.update()
  end

  defp update_shared_line_status(%SharedLine{} = shared_line, attrs) do
    shared_line
    |> SharedLine.status_changeset(attrs)
    |> Repo.update()
  end

  defp digits_only(value) when is_binary(value), do: String.replace(value, ~r/\D/, "")

  defp normalize_attrs(attrs) do
    for {key, value} <- Map.new(attrs), into: %{} do
      {to_string(key), value}
    end
  end
end
