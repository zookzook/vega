defmodule VegaWeb.CardsTest do
  use ExUnit.Case, async: true

  alias Vega.Board
  alias Vega.User
  alias Vega.Issue

  setup_all do
    #Mongo.create(:mongo, "boards")
    #Mongo.create(:mongo, "issues")
    #Mongo.create(:mongo, "cards")
    Mongo.create_indexes(:mongo, "cards", [[key: [list: 1, board: 1], name: "list_board"]])

    {:ok, [user: User.fetch()]}
  end

  test "create a board", context do
    user = context.user
    id = user._id
    title = "A board title"
    board = Board.new(title, user)
    assert board != nil
    assert board.title == title
    assert %{"admin" => ^id} = board.members
    assert {:ok, 0, 0} == Board.delete(board)
  end

  test "add new list to board", context do

    user = context.user
    title = "A board title"
    board = Board.new(title, user)
    assert board != nil

    title = "to do"
    board = Board.add_list(board, user, title)
    assert board != nil
    assert (board.lists |> Enum.empty?()) == false

    [list] = board.lists

    assert list.title == title

    [issue] = Issue.fetch_all(board) |> Enum.to_list()
    assert issue.board == board._id
    assert issue.t == %Vega.Issue.AddList{m: 4, title: "to do"}
    assert {:ok, 1, 0} == Board.delete(board)

  end

  test "add new card to board", context do

    user = context.user
    title = "A board title"
    board = Board.new(title, user)
    assert board != nil

    title = "to do"
    board = Board.add_list(board, user, title)

    [list] = board.lists

    card_title = "My card title"
    board = Board.add_card(board, list, user, card_title)

    [list] = board.lists

    cards = list.cards
    assert Enum.empty?(cards) == false
    [card] = cards
    assert card.title == card_title

    assert {:ok, 2, 1} == Board.delete(board)
  end

  test "add many cards to board", context do

    user = context.user
    title = "A board title"
    board = Board.new(title, user)
    assert board != nil

    board = Board.add_list(board, user, "to do")
    board = Board.add_list(board, user, "doing")
    board = Board.add_list(board, user, "done")

    for list <- board.lists do
      for n <- 1..1000 do
        card_title = "My card title " <> to_string(n)
        Board.add_card(board, list, user, card_title, false)
      end
    end

    board = Board.fetch(board)
    assert {:ok, 3003, 3000} == Board.delete(board)
  end

  test "ordering of lists", context do

    user = context.user
    title = "A board title"
    board = Board.new(title, user)
    assert board != nil

    board = Board.add_list(board, user, "to do")
    board = Board.add_list(board, user, "doing")
    board = Board.add_list(board, user, "done")

    [a, b, c] = board.lists

    assert (a.ordering < b.ordering && b.ordering < c.ordering) == true

    assert {:ok, 3, 0} == Board.delete(board)

  end

  test "delete a list", context do

    user = context.user
    title = "A board title"
    board = Board.new(title, user)
    assert board != nil

    board = Board.add_list(board, user, "to do")
    board = Board.add_list(board, user, "doing")
    board = Board.add_list(board, user, "done")

    [a, b, c] = board.lists

    assert (a.ordering < b.ordering && b.ordering < c.ordering) == true

    assert a.ordering == 0
    assert b.ordering == 1
    assert c.ordering == 2

    board = Board.delete_list(board, user, a)

    [b, c] = board.lists

    assert (b.ordering < c.ordering) == true
    assert b.ordering == 0
    assert c.ordering == 1

    assert {:ok, 4, 0} == Board.delete(board)

  end


end