defmodule VegaWeb.PageController do
  use VegaWeb, :controller

  alias Vega.BoardOverview

  @doc """
  Render the overview of the boards connected to the current user
  """
  def index(conn, _params) do

    {personal, visited, starred} = conn
                                   |> fetch_user()
                                   |> BoardOverview.fetch_all_for_user()

    conn
    |> merge_assigns(personal: personal, visited: visited, starred: starred)
    |> merge_assigns(css: "welcome", js: "welcome")
    |> assign_asserts("welcome")
    |> render("index.html")
  end



end
