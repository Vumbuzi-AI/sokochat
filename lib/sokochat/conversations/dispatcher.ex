defmodule Sokochat.Conversations.Dispatcher do
  @moduledoc """
  Orchestrates inbound conversation handling for playground and channel integrations.
  """

  alias Sokochat.AI.ContextBuilder
  alias Sokochat.AI.CtaInjector
  alias Sokochat.AI.OpenAIClient
  alias Sokochat.AI.Retriever
  alias Sokochat.Catalogs
  alias Sokochat.Conversations
  alias Sokochat.Conversations.ProductCTA
  alias Sokochat.Endpoints
  alias Sokochat.Repo
  alias Sokochat.Workspaces.Workspace

  def dispatch(workspace_id, phone_number, user_message, source \\ :playground) do
    with {:ok, prepared} <- prepare_dispatch(workspace_id) do
      dispatch_prepared(prepared, phone_number, user_message, source)
    end
  end

  def prepare_dispatch(workspace_id) do
    workspace = Repo.get!(Workspace, workspace_id)
    endpoint = Endpoints.get_endpoint(workspace.id)
    cta_rules = cta_rules_for(workspace.id)

    with {:ok, endpoint_data} <- endpoint_data_for_dispatch(endpoint) do
      business_context =
        Catalogs.build_workspace_context(workspace.id, endpoint_data, workspace.data_source)

      {:ok,
       %{
         workspace: workspace,
         endpoint: Endpoints.get_endpoint(workspace.id) || endpoint,
         cta_rules: cta_rules,
         endpoint_data: business_context,
         system_prompt:
           workspace
           |> ContextBuilder.build_system_prompt(business_context)
           |> CtaInjector.inject_cta_rules(cta_rules)
       }}
    end
  end

  def dispatch_prepared(prepared, phone_number, user_message, source \\ :playground) do
    %{workspace: workspace, endpoint_data: endpoint_data} = prepared
    system_prompt = system_prompt_for(prepared, user_message)

    with {:ok, conversation} <-
           Conversations.get_or_create_conversation(workspace.id, phone_number, source),
         {:ok, saved_user_message} <-
           Conversations.add_message(conversation, :user, user_message,
             endpoint_snapshot: endpoint_data
           ),
         messages <- Conversations.build_messages(conversation.id, user_message),
         {:ok, reply} <- OpenAIClient.chat(messages, system_prompt),
         final_cta = ProductCTA.attach(reply.reply, user_message, endpoint_data, reply.cta),
         {:ok, assistant_message} <-
           Conversations.add_message(conversation, :assistant, reply.reply,
             cta: final_cta,
             tokens_used: reply.tokens
           ) do
      maybe_broadcast_to_playground(workspace.id, source, saved_user_message)
      Conversations.broadcast_new_message(assistant_message)
      maybe_broadcast_to_playground(workspace.id, source, assistant_message)
      {:ok, assistant_message}
    end
  end

  # For catalog-backed workspaces, retrieve only the items semantically relevant
  # to the buyer's message (RAG). The prompt stays a constant size no matter how
  # large the catalog is, and the bot always sees the right products.
  defp system_prompt_for(
         %{workspace: %Workspace{data_source: "manual"} = workspace, cta_rules: cta_rules},
         user_message
       ) do
    retrieved = Retriever.search(workspace.id, user_message)
    categories = Catalogs.list_item_categories(workspace.id)

    workspace
    |> ContextBuilder.build_system_prompt(retrieved, all_categories: categories)
    |> CtaInjector.inject_cta_rules(cta_rules)
  end

  # Re-scope the system prompt to a single category when the buyer's message
  # names one, so that category's products are streamed in full instead of being
  # lost to catalog truncation. Falls back to the precomputed broad prompt.
  defp system_prompt_for(
         %{
           workspace: workspace,
           endpoint_data: endpoint_data,
           cta_rules: cta_rules,
           system_prompt: system_prompt
         },
         user_message
       ) do
    case ContextBuilder.detect_focus_category(endpoint_data, user_message) do
      nil ->
        system_prompt

      category ->
        workspace
        |> ContextBuilder.build_system_prompt(endpoint_data, focus_category: category)
        |> CtaInjector.inject_cta_rules(cta_rules)
    end
  end

  defp system_prompt_for(%{system_prompt: system_prompt}, _user_message), do: system_prompt

  defp endpoint_data_for_dispatch(nil), do: {:ok, nil}

  defp endpoint_data_for_dispatch(%{refresh_strategy: "on_demand"} = endpoint) do
    Endpoints.fetch_live_data(endpoint)
  end

  defp endpoint_data_for_dispatch(%{cached_data: cached_data}) when not is_nil(cached_data) do
    {:ok, cached_data}
  end

  defp endpoint_data_for_dispatch(endpoint) do
    case Endpoints.refresh_cached_data(endpoint) do
      {:ok, refreshed_endpoint} -> {:ok, refreshed_endpoint.cached_data}
      {:error, reason} -> {:error, reason}
    end
  end

  defp cta_rules_for(workspace_id) do
    module = Sokochat.CTARules

    if Code.ensure_loaded?(module) and function_exported?(module, :list_cta_rules, 1) do
      apply(module, :list_cta_rules, [workspace_id])
    else
      []
    end
  end

  defp maybe_broadcast_to_playground(workspace_id, source, assistant_message) do
    if normalize_source(source) == "playground" do
      Conversations.broadcast_playground_message(workspace_id, assistant_message)
    end
  end

  defp normalize_source(source) when is_atom(source), do: Atom.to_string(source)
  defp normalize_source(source) when is_binary(source), do: source
end
