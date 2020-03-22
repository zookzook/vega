defmodule VegaWeb.CardsTest do
  use ExUnit.Case, async: true

  alias Vega.Board
  alias Vega.User

  setup_all do
    {:ok, [user: User.fetch()]}
  end

  test "add cards with natural order", context do

    user = context.user
    title = "A board title"
    board = Board.new(title, user)
    assert board != nil

    board = Board.add_list(board, user, "to do")

    [a] = board.lists

    board = Board.add_card(board, a, user, "A new card 1")

    [a] = board.lists
    board = Board.add_card(board, a, user, "A new card 2")

    [a] = board.lists
    board = Board.add_card(board, a, user, "A new card 3")

    [a] = board.lists

    [card_1, card_2, card_3] = a.cards

    assert card_1.pos == 1.0
    assert card_2.pos == 2.0
    assert card_3.pos == 3.0

    assert {:ok, 4, 3} == Board.delete(board)

  end

  test "add cards to a list", context do

    user = context.user
    title = "A board title"
    board = Board.new(title, user)
    assert board != nil

    new_titles = ["this", "is", "a", "test"]

    board = Board.add_list(board, user, "to do")
    [a] = board.lists

    board = Board.add_cards(board, a, user, new_titles)
    [a] = board.lists

    [card_1, card_2, card_3, card_4] = a.cards

    assert card_1.pos == 1.0
    assert card_2.pos == 2.0
    assert card_3.pos == 3.0
    assert card_4.pos == 4.0

    assert {:ok, 5, 4} == Board.delete(board)
  end

  test "move card within a list", context do

    user = context.user
    title = "A board title"
    board = Board.new(title, user)
    assert board != nil

    board      = Board.add_list(board, user, "to do")
    [a]        = board.lists
    new_titles = ["this", "is", "a", "test"]
    board      = Board.add_cards(board, a, user, new_titles)
    [a]        = board.lists

    [card_1, _card_2, _card_3, card_4] = a.cards

    board = Board.move_card_before(user, board, a, card_4._id, card_1._id)
    [a]   = board.lists
    [card_1, card_2, card_3, card_4] = a.cards

    assert card_1.title == "test"
    assert card_2.title == "this"
    assert card_3.title == "is"
    assert card_4.title == "a"

    board = Board.move_card_before(user, board, a, card_4._id, card_2._id)
    [a]   = board.lists
    [card_1, card_2, card_3, card_4] = a.cards

    assert card_1.title == "test"
    assert card_2.title == "a"
    assert card_3.title == "this"
    assert card_4.title == "is"

    board = Board.move_card_before(user, board, a, card_1._id, card_4._id)
    [a]   = board.lists
    [card_1, card_2, card_3, card_4] = a.cards

    assert card_1.title == "a"
    assert card_2.title == "this"
    assert card_3.title == "test"
    assert card_4.title == "is"

    board = Board.move_card_before(user, board, a, card_2._id, card_1._id)
    [a]   = board.lists
    [_card_1, card_2, _card_3, card_4] = a.cards

    board = Board.move_card_before(user, board, a, card_4._id, card_2._id)
    [a]   = board.lists
    [card_1, card_2, card_3, card_4] = a.cards

    assert card_1.title == "this"
    assert card_2.title == "is"
    assert card_3.title == "a"
    assert card_4.title == "test"

    assert [0.375, 0.5625, 0.75, 1.5] == Enum.map(a.cards, fn %{pos: pos} -> pos end)
    assert {:ok, 10, 4} == Board.delete(board)

  end



end
