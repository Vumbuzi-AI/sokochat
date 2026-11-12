defmodule SokochatWeb.PageControllerTest do
  use SokochatWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "Turn WhatsApp chats"
    assert response =~ "AI answers customers from your catalogue"
    assert response =~ "List your shop"
  end
end
