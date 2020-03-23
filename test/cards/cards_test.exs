defmodule VegaWeb.CardsTest do
  use ExUnit.Case, async: true

  alias Vega.Board
  alias Vega.User

  setup_all do
    {:ok, [user: User.fetch()]}
  end

  describe "adding cards" do

    test "add cards with natural order", context do

      user = context.user
      title = "A board title"
      board = Board.new(user, title)
      assert board != nil

      board = Board.add_list(board, user, "to do")

      [a] = board.lists

      board = Board.add_card(board, user, a, "A new card 1")

      [a] = board.lists
      board = Board.add_card(board, user, a, "A new card 2")

      [a] = board.lists
      board = Board.add_card(board, user, a, "A new card 3")

      [a] = board.lists

      [card_1, card_2, card_3] = a.cards

      assert card_1.pos == 100.0
      assert card_2.pos == 200.0
      assert card_3.pos == 300.0

      assert {:ok, 4, 3} == Board.delete(board)

    end

    test "add cards to a list", context do

      user = context.user
      title = "A board title"
      board = Board.new(user, title)
      assert board != nil

      new_titles = ["this", "is", "a", "test"]

      board = Board.add_list(board, user, "to do")
      [a] = board.lists

      board = Board.add_cards(board, user, a, new_titles)
      [a] = board.lists

      [card_1, card_2, card_3, card_4] = a.cards

      assert card_1.pos == 100.0
      assert card_2.pos == 200.0
      assert card_3.pos == 300.0
      assert card_4.pos == 400.0

      assert {:ok, 5, 4} == Board.delete(board)
    end

  end

  describe "move cards" do

    test "move card before other card", context do

      user = context.user
      title = "A board title"
      board = Board.new(user, title)
      assert board != nil

      board      = Board.add_list(board, user, "to do")
      [a]        = board.lists
      new_titles = ["this", "is", "a", "test"]
      board      = Board.add_cards(board, user, a, new_titles)
      [a]        = board.lists

      [card_1, _card_2, _card_3, card_4] = a.cards

      board = Board.move_card_before(board, user, a, card_4, card_1)
      [a]   = board.lists
      [card_1, card_2, card_3, card_4] = a.cards

      assert card_1.title == "test"
      assert card_2.title == "this"
      assert card_3.title == "is"
      assert card_4.title == "a"

      board = Board.move_card_before(board, user, a, card_4, card_2)
      [a]   = board.lists
      [card_1, card_2, card_3, card_4] = a.cards

      assert card_1.title == "test"
      assert card_2.title == "a"
      assert card_3.title == "this"
      assert card_4.title == "is"

      board = Board.move_card_before(board, user, a, card_1, card_4)
      [a]   = board.lists
      [card_1, card_2, card_3, card_4] = a.cards

      assert card_1.title == "a"
      assert card_2.title == "this"
      assert card_3.title == "test"
      assert card_4.title == "is"

      board = Board.move_card_before(board, user, a, card_2, card_1)
      [a]   = board.lists
      [_card_1, card_2, _card_3, card_4] = a.cards

      board = Board.move_card_before(board, user, a, card_4, card_2)
      [a]   = board.lists
      [card_1, card_2, card_3, card_4] = a.cards

      assert card_1.title == "this"
      assert card_2.title == "is"
      assert card_3.title == "a"
      assert card_4.title == "test"

      assert [37.5, 56.25, 75.0, 150.0] == Enum.map(a.cards, fn %{pos: pos} -> pos end)
      assert {:ok, 10, 4} == Board.delete(board)

    end

    test "move card to the end", context do

      user = context.user
      title = "A board title"
      board = Board.new(user, title)
      assert board != nil

      board      = Board.add_list(board, user, "to do")
      [a]        = board.lists
      new_titles = ["this", "is", "a", "test"]
      board      = Board.add_cards(board, user, a, new_titles)
      [a]        = board.lists

      [card_1 | _xs] = a.cards

      board = Board.move_card_to_end(board, user, a, card_1)
      [a]   = board.lists
      [card_1, card_2, card_3, card_4] = a.cards

      assert card_1.title == "is"
      assert card_2.title == "a"
      assert card_3.title == "test"
      assert card_4.title == "this"

      board = Board.move_card_to_end(board, user, a, card_1)
      [a]   = board.lists
      [card_1, card_2, card_3, card_4] = a.cards

      assert card_1.title == "a"
      assert card_2.title == "test"
      assert card_3.title == "this"
      assert card_4.title == "is"

      board = Board.move_card_to_end(board, user, a, card_1)
      [a]   = board.lists
      [card_1, card_2, card_3, card_4] = a.cards

      assert card_1.title == "test"
      assert card_2.title == "this"
      assert card_3.title == "is"
      assert card_4.title == "a"

      board = Board.move_card_to_end(board, user, a, card_1)
      [a]   = board.lists
      [card_1, card_2, card_3, card_4] = a.cards

      assert card_1.title == "this"
      assert card_2.title == "is"
      assert card_3.title == "a"
      assert card_4.title == "test"

      assert [500.0, 600.0, 700.0, 800.0] == Enum.map(a.cards, fn %{pos: pos} -> pos end)
      assert {:ok, 9, 4} == Board.delete(board)

    end

    test "sort cards", context do

      user = context.user
      title = "A board title"
      board = Board.new(user, title)
      assert board != nil

      board      = Board.add_list(board, user, "to do")
      [a]        = board.lists
      new_titles = ["this", "is", "a", "test"]
      board      = Board.add_cards(board, user, a, new_titles)
      [a]        = board.lists

      cards = Enum.sort(a.cards, fn left, right -> left.title <= right.title end)
      board      = Board.sort_cards(board, user, cards, "asc title")
      [a]        = board.lists

      assert ["a", "is", "test", "this"]  == Enum.map(a.cards, fn %{title: title} -> title end)
      assert [100.0, 200.0, 300.0, 400.0] == Enum.map(a.cards, fn %{pos: pos} -> pos end)

      cards = Enum.sort(a.cards, fn left, right -> left.title >= right.title end)
      board = Board.sort_cards(board, user, cards, "desc title")
      [a]   = board.lists

      assert ["this", "test", "is", "a"]  == Enum.map(a.cards, fn %{title: title} -> title end)
      assert [100.0, 200.0, 300.0, 400.0] == Enum.map(a.cards, fn %{pos: pos} -> pos end)

      cards = Enum.sort(a.cards, fn left, right -> left.created <= right.created end)
      board = Board.sort_cards(board, user, cards, "asc created")
      [a]   = board.lists

      assert ["this", "is", "a", "test"]  == Enum.map(a.cards, fn %{title: title} -> title end)
      assert [100.0, 200.0, 300.0, 400.0] == Enum.map(a.cards, fn %{pos: pos} -> pos end)

      assert {:ok, 8 , 4} == Board.delete(board)

    end
  end

end
