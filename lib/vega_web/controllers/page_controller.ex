defmodule VegaWeb.PageController do
  use VegaWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
