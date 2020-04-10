defmodule VegaWeb.BoardTest do
  use ExUnit.Case, async: true

  alias Vega.Board
  alias Vega.User
  alias Vega.Issue
  alias Vega.WarningColorRule

  setup_all do
    {:ok, [user: User.fake("zookzok", "Mr. Zookzook", "zookzook@lvh.me")]}
  end

  describe "basic board CRUD functions" do
    test "create a board", context do
      user = context.user
      id = user._id
      title = "A board title"
      board = Board.new(user, title)
      assert board != nil
      assert board.title == title
      assert %{"id" => ^id, "role" => "admin"} = board.members
      assert {:ok, 1, 0} == Board.delete(board)
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

      assert {:ok, 2, 0} == Board.delete(board)
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

      assert {:ok, 4, 0} == Board.delete(board)
    end

    test "set color", context do
      user = context.user
      title = "A board"
      board = Board.new(user, title)

      color = "red"
      board = Board.set_color(board, user, "red")
      assert Keyword.get(board.options, :color) == color

      color = "blue"
      board = Board.set_color(board, user, "blue")
      assert Keyword.get(board.options, :color) == color

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

      [issue,_] = Issue.fetch_all(board) |> Enum.to_list()
      assert issue.board == board._id
      assert issue.t == 4
      assert {:ok, 2, 0} == Board.delete(board)

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

      assert {:ok, 4, 0} == Board.delete(board)

    end

    test "renaming a list", context do

      user = context.user
      title = "A board title"
      board = Board.new(user, title)
      assert board != nil

      board = Board.add_list(board, user, "to do")
      board = Board.add_list(board, user, "doing")
      board = Board.add_list(board, user, "done")

      [_a, b, _c] = board.lists

      board = Board.set_list_title(board, b, user, "in progress")
      [_a, b, _c] = board.lists

      assert b.title == "in progress"

      assert {:ok, 5, 0} == Board.delete(board)
    end

    test "set and remove color of list", context do

      user = context.user
      title = "A board title"
      board = Board.new(user, title)
      assert board != nil

      board = Board.add_list(board, user, "to do")
      [a] = board.lists

      assert nil == WarningColorRule.new("none", 10, "none")

      rule = WarningColorRule.new("green", 10, "red")
      board = Board.set_list_color(board, a, user, rule)
      [a] = board.lists

      assert rule == a.color

      board = Board.set_list_color(board, a, user, nil)
      [a] = board.lists

      assert a.color == nil

      assert {:ok, 4, 0} == Board.delete(board)
    end

    test "moving a list", context do

      user = context.user
      title = "A board title"
      board = Board.new(user, title)
      assert board != nil

      board = Board.add_list(board, user, "to do")
      board = Board.add_list(board, user, "doing")
      board = Board.add_list(board, user, "done")

      [a, b, c] = board.lists

      assert (a.pos < b.pos && b.pos < c.pos) == true

      board = Board.move_list(user, c, board, a)
      [a, b, c] = board.lists
      assert (a.pos < b.pos && b.pos < c.pos) == true
      assert a.title == "done"
      assert b.title == "to do"
      assert c.title == "doing"

      board = Board.move_list(user, c, board, a)
      [a, b, c] = board.lists
      assert (a.pos < b.pos && b.pos < c.pos) == true
      assert a.title == "doing"
      assert b.title == "done"
      assert c.title == "to do"

      board = Board.move_list(user, c, board, a)
      [a, b, c] = board.lists
      assert (a.pos < b.pos && b.pos < c.pos) == true
      assert a.title == "to do"
      assert b.title == "doing"
      assert c.title == "done"

      assert [12.5, 25.0, 50.0] == [a, b, c] |> Enum.map(fn l -> l.pos end)

      board = Board.move_list(user, a, board, nil)
      [a, b, c] = board.lists
      assert (a.pos < b.pos && b.pos < c.pos) == true

      assert [25.0, 50.0, 150.0] == [a, b, c] |> Enum.map(fn l -> l.pos end)
      assert {:ok, 8, 0} == Board.delete(board)

    end

    test "copy a list", context do

      user = context.user
      title = "A board title"
      board = Board.new(user, title)
      assert board != nil

      board = Board.add_list(board, user, "to do")
      for list <- board.lists do
        cards = Enum.map(1..10, fn i -> "My card title " <> to_string(i) end)
        Board.add_cards(board, user, list, cards)
      end

      board = Board.fetch(board)
      [a]   = board.lists

      board  = Board.copy_list(board, user, a, "done")
      [a, b] = board.lists

      assert a.title == "to do"
      assert b.title == "done"

      template_names = Enum.map(1..10, fn i -> "My card title " <> to_string(i) end) |> MapSet.new()
      names = b.cards |> Enum.map(fn card -> card.title end) |> MapSet.new()

      assert template_names == names
      assert {:ok, 13, 20} == Board.delete(board)

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

      assert a.pos == 100.0
      assert b.pos == 200.0
      assert c.pos == 300.0

      board = Board.delete_list(board, user, a)

      [b, c] = board.lists

      assert (b.pos < c.pos) == true
      assert b.pos == 200.0
      assert c.pos == 300.0

      assert {:ok, 5, 0} == Board.delete(board)

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

    assert {:ok, 3, 1} == Board.delete(board)
  end

  @max_cards 10

  test "move all cards of a list", context do

    user = context.user
    title = "A board title"
    board = Board.new(user, title)
    assert board != nil

    board = Board.add_list(board, user, "to do")
    board = Board.add_list(board, user, "doing")

    [a,_] = board.lists
    cards = Enum.map(1..@max_cards, fn i -> "My card title " <> to_string(i) end)
    Board.add_cards(board, user, a, cards)

    board = Board.fetch(board)
    [a,b] = board.lists

    board = Board.move_cards_of_list(board, a, b, user)
    [a,b] = board.lists

    assert 0 == length(a.cards)
    assert @max_cards == length(b.cards)

    assert {:ok, 14, 10} == Board.delete(board)
  end

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

    n_issues = 3 * @max_cards + 4
    n_cards  = 3 * @max_cards
    assert {:ok, ^n_issues, ^n_cards} = Board.delete(board)
  end

  describe "moving list from board to board" do

    test "move a list to end of an empty board", context do
      user = context.user
      title = "From board"
      from = Board.new(user, title)

      from = Board.add_list(from, user, "to do")
      from = Board.add_list(from, user, "doing")
      from = Board.add_list(from, user, "done")

      for list <- from.lists do
        cards = Enum.map(1..5, fn i -> "My card title " <> to_string(i) end)
        Board.add_cards(from, user, list, cards)
      end

      title = "To board"
      to = Board.new(user, title)

      from = Board.fetch(from)
      [_a,_b,c] = from.lists

      to = Board.fetch(to)

      from = Board.move_list(user, from, c, to)
      to = Board.fetch(to)

      assert [_a,_b] = from.lists
      assert [c] = to.lists

      assert c.title == "done"
      assert length(c.cards) == 5

      assert {:ok, 20, 10} == Board.delete(from)
      assert {:ok, 2, 5} == Board.delete(to)
    end

    test "move a list to end non empty board", context do
      user = context.user
      title = "From board"
      from = Board.new(user, title)

      from = Board.add_list(from, user, "to do")
      from = Board.add_list(from, user, "doing")
      from = Board.add_list(from, user, "done")

      for list <- from.lists do
        cards = Enum.map(1..5, fn i -> "My card title " <> to_string(i) end)
        Board.add_cards(from, user, list, cards)
      end

      title = "To board"
      to = Board.new(user, title)
      to = Board.add_list(to, user, "to do")
      to = Board.add_list(to, user, "doing")

      for list <- to.lists do
        cards = Enum.map(1..5, fn i -> "My card title " <> to_string(i) end)
        Board.add_cards(to, user, list, cards)
      end

      from = Board.fetch(from)
      [_a,_b,c] = from.lists

      to = Board.fetch(to)

      from = Board.move_list(user, from, c, to)
      to = Board.fetch(to)

      assert [_a,_b] = from.lists
      assert [_a,_b,c] = to.lists

      assert c.title == "done"

      assert {:ok, 20, 10} == Board.delete(from)
      assert {:ok, 14, 15} == Board.delete(to)
    end
  end

end