defmodule VegaWeb.PageController do
  use VegaWeb, :controller

  alias Vega.BoardOverview

  @doc """
  Render the overview of the boards connected to the current user
  """
  def index(conn, _params) do

    {personal, visited, starred, closed} = conn
                                           |> fetch_user()
                                           |> BoardOverview.fetch_all_for_user()

    conn
    |> merge_assigns(personal: personal, visited: visited, starred: starred, closed: closed)
    |> assign_asserts("welcome")
    |> render("index.html")
  end

  def clear_db(conn, _param) do

    Mongo.delete_many(:mongo, "cards", %{})
    Mongo.delete_many(:mongo, "issues", %{})
    Mongo.delete_many(:mongo, "boards", %{})

    conn
    |> merge_assigns(personal: [], visited: [], starred: [])
    |> assign_asserts("welcome")
    |> render("index.html")
  end


end
