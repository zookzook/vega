defmodule Vega.IssueConsts do
  @moduledoc """

  This module contains the constant of all issues. Each modification is recorded as an issue, so we have the whole
  history of modifications of the board, lists and cards.

  """

  values = [
    new_board: 0,
    set_description: 1,
    set_title: 2,
    add_comment: 3,
    add_list: 4,
    new_card: 5,
    delete_list: 6,
    set_board_color: 7,
    sort_cards: 8,
    move_card: 9,
    move_list: 10,
    copy_list: 11,
    set_list_color: 12,
    move_cards_of_list: 13,
    archive_card: 14,
    archive_list: 15,
    close_board: 16,
    unarchive_card: 17,
    unarchive_list: 18,
    open_board: 19,
    clone_board: 20
  ]

  for {key, value} <- values do
    def encode(unquote(key)),   do: unquote(value)
    def decode(unquote(value)), do: unquote(key)
  end

end