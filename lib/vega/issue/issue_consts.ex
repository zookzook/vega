defmodule Vega.IssueConsts do

  values = [new_board: 0,
    set_description: 1,
    set_title: 2,
    add_comment: 3,
    add_list: 4,
    new_card: 5,
    delete_list: 6,
    reorder_list: 7,
    sort_cards: 8,
    move_card: 9]

  for {key, value} <- values do
    def encode(unquote(key)),   do: unquote(value)
    def decode(unquote(value)), do: unquote(key)
  end

end