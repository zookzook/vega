defmodule VegaWeb.BoardTest do
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

  describe "basic board CRUD functions" do
    test "create a board", context do
      user = context.user
      id = user._id
      title = "A board title"
      board = Board.new(user, title)
      assert board != nil
      assert board.title == title
      assert %{"admin" => ^id} = board.members
      assert {:ok, 0, 0} == Board.delete(board)
    end

    test "set title", context do
      user = context.user
      title = "A board title"
      board = Board.new(user, title)
      assert board != nil
      assert board.title == title

      title = "The new title"

      board = Board.set_title(board, user, title)
      assert board.title == title

      assert {:ok, 1, 0} == Board.delete(board)
    end

    test "set description", context do
      user = context.user
      title = "A board title"
      board = Board.new(user, title)
      description = "## Hello ##"
      board = Board.set_description(board, user, description)
      assert board.description == description

      description = "## Welcome ##"
      board = Board.set_description(board, user, description)
      assert board.description == description

      description = nil
      board = Board.set_description(board, user, description)
      assert board.description == description

      assert {:ok, 3, 0} == Board.delete(board)
    end
  end

  describe "basic list CRUD functions" do

    test "add new list to board", context do

      user = context.user
      title = "A board title"
      board = Board.new(user, title)
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
  end



  test "add new card to board", context do

    user = context.user
    title = "A board title"
    board = Board.new(user, title)
    assert board != nil

    title = "to do"
    board = Board.add_list(board, user, title)

    [list] = board.lists

    card_title = "My card title"
    board = Board.add_card(board, user, list, card_title)

    [list] = board.lists

    cards = list.cards
    assert Enum.empty?(cards) == false
    [card] = cards
    assert card.title == card_title

    assert {:ok, 2, 1} == Board.delete(board)
  end

  @max_cards 10

  test "add many cards to board", context do

    user = context.user
    title = "A board title"
    board = Board.new(user, title)
    assert board != nil

    board = Board.add_list(board, user, "to do")
    board = Board.add_list(board, user, "doing")
    board = Board.add_list(board, user, "done")

    for list <- board.lists do
      cards = Enum.map(1..@max_cards, fn i -> "My card title " <> to_string(i) end)
      Board.add_cards(board, user, list, cards)
    end

    board = Board.fetch(board)

    n_issues = 3 * @max_cards + 3
    n_cards  = 3 * @max_cards
    assert {:ok, ^n_issues, ^n_cards} = Board.delete(board)
  end

  test "ordering of lists", context do

    user = context.user
    title = "A board title"
    board = Board.new(user, title)
    assert board != nil

    board = Board.add_list(board, user, "to do")
    board = Board.add_list(board, user, "doing")
    board = Board.add_list(board, user, "done")

    [a, b, c] = board.lists

    assert (a.pos < b.pos && b.pos < c.pos) == true

    assert {:ok, 3, 0} == Board.delete(board)

  end

  test "delete a list", context do

    user = context.user
    title = "A board title"
    board = Board.new(user, title)
    assert board != nil

    board = Board.add_list(board, user, "to do")
    board = Board.add_list(board, user, "doing")
    board = Board.add_list(board, user, "done")

    [a, b, c] = board.lists

    assert (a.pos < b.pos && b.pos < c.pos) == true

    assert a.pos == 0
    assert b.pos == 1
    assert c.pos == 2

    board = Board.delete_list(board, user, a)

    [b, c] = board.lists

    assert (b.pos < c.pos) == true
    assert b.pos == 0
    assert c.pos == 1

    assert {:ok, 4, 0} == Board.delete(board)

  end


end