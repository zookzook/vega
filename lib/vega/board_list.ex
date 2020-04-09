defmodule Vega.BoardList do
  @moduledoc false

  alias Vega.BoardList
  alias Vega.Card
  alias Vega.WarningColorRule

  defstruct [
    :_id,       ## the ObjectId of the list
    :id,        ## the ObjectId as a string
    :pos,       ## current pos
    :title,     ## the title
    :cards,     ## the cards (fetched)
    :n_cards,   ## the number of cards (buffered)
    :color      ## the color rule of the list
  ]

  def new(title, pos) do
    %BoardList{_id: Mongo.object_id(), title: title, pos: pos, color: WarningColorRule.new("default", 3, "red")}
  end

  def to_struct(%{"_id" => id, "title" => title, "pos" => pos} = doc) do
    cards        = Card.fetch_all_in_list(id) |> Enum.sort({:asc, Card})
    warningColor = WarningColorRule.to_struct(doc["color"])
    %BoardList{_id: id, id: BSON.ObjectId.encode!(id) ,pos: pos, title: title, cards: cards, n_cards: length(cards), color: warningColor}
  end

  def find_card(board, card_id) when is_binary(card_id) do
    find_card(board, BSON.ObjectId.decode!(card_id))
  end
  def find_card(%BoardList{cards: cards}, card_id) do
    Enum.find(cards, fn %Card{_id: id} -> id == card_id end)
  end

  @doc """
  Used for sorting: compare the pos value.
  """
  def compare(a, b) do
    case a.pos - b.pos do
      x when x < 0 -> :lt
      x when x > 0 -> :gt
      _            -> :eq
    end
  end

end
