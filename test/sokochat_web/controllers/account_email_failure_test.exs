defmodule SokochatWeb.AccountEmailFailureTest do
  use SokochatWeb.ConnCase, async: false

  alias Sokochat.{Accounts, Mailer, Repo}
  import Sokochat.AccountsFixtures

  defmodule ExitingAdapter do
    use Swoosh.Adapter
    def deliver(_email, _config), do: exit(:noproc)
  end

  defmodule RaisingAdapter do
    use Swoosh.Adapter
    def deliver(_email, _config), do: raise("private-provider-diagnostic")
  end

  setup do
    previous = Application.fetch_env!(:sokochat, Mailer)
    on_exit(fn -> Application.put_env(:sokochat, Mailer, previous) end)
    :ok
  end

  for {label, adapter} <- [
        {"unconfigured", Sokochat.Mailer.UnconfiguredAdapter},
        {"exiting", ExitingAdapter},
        {"raising", RaisingAdapter}
      ] do
    @tag :capture_log
    test "registration survives an #{label} mail adapter", %{conn: conn} do
      Application.put_env(:sokochat, Mailer, adapter: unquote(adapter))
      attrs = valid_user_attributes()
      conn = post(conn, ~p"/users/register", %{"user" => attrs})

      assert redirected_to(conn) == ~p"/workspaces/new"
      assert get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Your account is ready"
      user = Accounts.get_user_by_email(attrs.email)
      assert user
      assert is_nil(user.confirmed_at)
      assert Accounts.get_user_by_email_and_password(attrs.email, attrs.password)
    end
  end

  test "unconfigured recovery emails give the same result for existing and unknown accounts" do
    Application.put_env(:sokochat, Mailer, adapter: Sokochat.Mailer.UnconfiguredAdapter)
    user = user_fixture()

    for path <- [~p"/users/reset_password", ~p"/users/confirm"] do
      responses =
        for email <- [user.email, unique_user_email()] do
          conn = post(build_conn(), path, %{"user" => %{"email" => email}})
          assert redirected_to(conn) == path
          Phoenix.Flash.get(conn.assigns.flash, :error)
        end

      assert [message, message] = responses
      assert message =~ "unavailable right now"
    end

    assert Repo.all(Accounts.UserToken) == []
  end

  @tag :capture_log
  test "failed email change preserves the current address and the entered new address", %{
    conn: conn
  } do
    Application.put_env(:sokochat, Mailer, adapter: Sokochat.Mailer.UnconfiguredAdapter)
    user = user_fixture()
    email = unique_user_email()

    conn =
      conn
      |> log_in_user(user)
      |> put(~p"/users/settings", %{
        "action" => "update_email",
        "current_password" => valid_user_password(),
        "user" => %{"email" => email}
      })

    assert html_response(conn, 200) =~ email
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Your email hasn't changed"
    assert Accounts.get_user!(user.id).email == user.email
  end
end
