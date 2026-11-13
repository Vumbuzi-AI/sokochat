defmodule SokochatWeb.MarketingComponents do
  @moduledoc "Public footer designed on the Sokochat Doop canvas."
  use SokochatWeb, :html

  attr :current_user, :map, default: nil

  def footer(assigns) do
    assigns = assign(assigns, :year, Date.utc_today().year)

    ~H"""
    <footer class="soko-footer">
      <div class="sf-top">
        <div class="sf-invite">
          <h2>Put your shop<br />on Sokochat.</h2>
          <div class="sf-cta">
            <.button
              navigate={if @current_user, do: ~p"/workspaces", else: ~p"/users/register"}
              tone="secondary"
              size="lg"
            >
              {if @current_user, do: "Open your desk", else: "List your shop"}
            </.button>
          </div>
        </div>
        <nav aria-label="Footer" class="sf-links">
          <div>
            <p>Explore</p>
            <.link navigate={~p"/users/register"}>List your shop</.link>
            <.link navigate={~p"/users/log_in"}>Sign in</.link>
            <.link href={~p"/" <> "#how-it-works"}>How it works</.link>
          </div>
          <div>
            <p>Legal</p>
            <.link navigate={~p"/privacy"}>Privacy policy</.link>
            <.link navigate={~p"/terms"}>Terms of service</.link>
          </div>
        </nav>
      </div>
      <.link navigate={~p"/"} aria-label="Sokochat home" class="sf-brand">
        <span class="sf-mark" aria-hidden="true">
          <img src={~p"/images/logo.png"} alt="" width="1500" height="500" />
        </span>
        <span aria-hidden="true">Sokochat</span>
      </.link>
      <div class="sf-bottom">
        <span>© {@year} Sokochat</span>
        <a href="#top">Back to top <.icon name="arrow-up-right" class="h-3.5 w-3.5" /></a>
      </div>
    </footer>
    """
  end
end
