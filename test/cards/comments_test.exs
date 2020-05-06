defmodule VegaWeb.CommentsTest do
  use ExUnit.Case, async: true

  alias Vega.Board
  alias Vega.User
  # alias Vega.Card
  # alias Vega.Comment

  setup_all do
    {:ok, [user: User.fake("zookzok", "Mr. Zookzook", "zookzook@lvh.me")]}
  end

    test "add simple comment", context do

      user = context.user
      title = "A board title"
      board = Board.new(user, title)

      board = Board.add_list(board, user, "to do")
      [a] = board.lists

      board = Board.add_card(board, user, a, "A new card")
      [a] = board.lists
      [card] = a.cards

      board = Board.add_comment_to_card(board, card, "This is a comment", user)
      [a] = board.lists
      [card] = a.cards
      [comment] = card.comments

      assert comment.text == "This is a comment"

      assert {:ok, 4, 1} == Board.delete(board)
  end

end