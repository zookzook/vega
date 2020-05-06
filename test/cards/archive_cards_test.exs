defmodule VegaWeb.ArchiveCardsTest do
  use ExUnit.Case, async: true

  alias Vega.Board
  alias Vega.User

  setup_all do
    {:ok, [user: User.fake("zookzok", "Mr. Zookzook", "zookzook@lvh.me")]}
  end
  describe "workflow for archiving and unarchiving cards" do

    test "archive cards", context do

      user = context.user
      title = "Vega"
      board = Board.new(user, title)
      board = Board.add_list(board, user, "Features")
      [a]         = board.lists
      new_titles = ["this", "is", "a", "test"]
      board      = Board.add_cards(board, a, new_titles, user)
      [a]        = board.lists
      [card | _] = a.cards
      board      = Board.archive_card(board, card, user)
      [a]        = board.lists
      assert length(a.cards) == 3

      [_cards]   = Board.fetch_archived_cards(board, a) |> Enum.to_list()

      assert {:ok, 7, 4} == Board.delete(board)

    end

    test "unarchive cards", context do

      user = context.user
      title = "Vega"
      board = Board.new(user, title)
      board = Board.add_list(board, user, "Features")
      [a]         = board.lists
      new_titles = ["this", "is", "a", "test"]
      board      = Board.add_cards(board, a, new_titles, user)
      [a]        = board.lists

      cards = a.cards
      cards |> Enum.each(fn card -> Board.archive_card(board, card, user)  end)
      board = Board.fetch(board)
      [a]   = board.lists
      assert length(a.cards) == 0

      assert Board.fetch_archived_cards(board, a) |> Enum.to_list() |> length == 4

      cards |> Enum.each(fn card -> Board.unarchive_card(board, card, user)  end)
      board = Board.fetch(board)
      [a]   = board.lists
      assert length(a.cards) == 4

      assert Board.fetch_archived_cards(board, a) |> Enum.to_list() |> length == 0

      assert {:ok, 14, 4} == Board.delete(board)

    end

  end

end