defmodule VegaWeb.PageController do
  use VegaWeb, :controller

  alias Vega.User
  alias Vega.Board

  def index(conn, _params) do
    board = fetch_board()
    conn
    |> assign(:board, board)
    |> render("index.html")
  end

  def xfetch_board() do

    Mongo.delete_many(:mongo, "cards", %{})
    user = User.fetch()
    Mongo.create_indexes(:mongo, "cards", [[key: [list: 1, board: 1], name: "list_board"]])

    title = "A board title"
    board = Board.new(title, user)
    board = Board.add_list(board, user, "to do")
    board = Board.add_list(board, user, "doing")
    board = Board.add_list(board, user, "done")

    for list <- board.lists do
      for n <- 1..10 do
        card_title = "My card title " <> to_string(n)
        board = Board.add_card(board, list, user, card_title, false)
      end
    end

    {time, board} = :timer.tc(fn ->
      Board.fetch(board)
    end)

    IO.puts inspect time / 1000
    IO.puts inspect board._id

    board
  end

  def fetch_board() do

    {time, board} = :timer.tc(fn ->
      Board.fetch("5e72525f306a5f07b6100196")
    end)

    IO.puts inspect time / 1000

    board
  end
end
