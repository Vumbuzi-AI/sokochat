defmodule SokochatWeb.PageControllerTest do
  use SokochatWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "Your always-on WhatsApp sales team"
    assert response =~ "Turn WhatsApp conversations into"
    assert response =~ "Built for merchants, marketplaces, and growing teams across East Africa"
  end
end
