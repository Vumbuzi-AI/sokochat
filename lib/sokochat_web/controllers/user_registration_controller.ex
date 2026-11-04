defmodule SokochatWeb.UserRegistrationController do
  use SokochatWeb, :controller

  alias Sokochat.Accounts
  alias Sokochat.Accounts.User
  alias SokochatWeb.UserAuth

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, :new, changeset: changeset, form: Phoenix.Component.to_form(changeset))
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        delivery =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        message =
          case delivery do
            {:ok, _} ->
              "User created successfully."

            {:error, _} ->
              "Your account is ready. We couldn't send your confirmation email right now."
          end

        conn
        |> put_flash(:info, message)
        |> UserAuth.log_in_user(user, %{"redirect_to" => ~p"/workspaces/new"})

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset, form: Phoenix.Component.to_form(changeset))
    end
  end
end
