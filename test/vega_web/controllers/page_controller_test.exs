defmodule VegaWeb.PageControllerTest do
  use VegaWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Michael Maier"
  end
end
