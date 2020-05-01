defmodule Vega.BoardList do
  @moduledoc false

  import Vega.StructHelper

  alias Vega.BoardList
  alias Vega.Card
  alias Vega.WarningColorRule
  alias Mongo.UnorderedBulk

  @cards_collection "cards"

  @derived_attributes [:id]

  defstruct [
    :_id,       ## the ObjectId of the list
    :id,        ## the ObjectId as a string
    :pos,       ## current pos
    :title,     ## the title
    :cards,     ## the cards (fetched)
    :n_cards,   ## the number of cards (buffered)
    :color,     ## the color rule of the list
    :created,   ## creation date
    :archived   ## archiving date
  ]

  def new(title, pos) do
    %BoardList{_id: Mongo.object_id(), title: title, pos: pos, created: DateTime.utc_now()}
  end

  @doc """
  Create a deep copy. The result is a tuple with the new list and an unordered bulk operation for the cards to insert.
  """
  def clone(board, %BoardList{cards: cards} = list) do
    result = %BoardList{list | _id: Mongo.object_id, cards: nil, n_cards: nil }
    bulk = UnorderedBulk.new(@cards_collection)
    bulk = Enum.reduce(cards, bulk, fn card, bulk -> UnorderedBulk.insert_one(bulk, Card.clone(board, result, card) |> to_map()) end)
    {list._id, result, bulk}
  end

  def dump(%BoardList{} = list) do
    list
    |> Map.drop(@derived_attributes)
    |> to_map()
  end

  def load(%{"_id" => id, "title" => title, "pos" => pos} = doc) do
    cards        = Card.fetch_all_in_list(id) |> Enum.sort({:asc, Card})
    warningColor = WarningColorRule.load(doc["color"])
    %BoardList{
      _id: id,
      id: BSON.ObjectId.encode!(id),
      pos: pos,
      title: title,
      cards: cards,
      n_cards: length(cards),
      color: warningColor,
      created: doc["created"],
      archived: doc["archived"]}
  end

  def find_card(board, card_id) when is_binary(card_id) do
    find_card(board, BSON.ObjectId.decode!(card_id))
  end
  def find_card(%BoardList{cards: cards}, card_id) do
    Enum.find(cards, fn %Card{_id: id} -> id == card_id end)
  end

  def is_archived(%BoardList{archived: date}) do
    date != nil
  end
  def is_archived(%{"archived" => date}) do
    date != nil
  end
  def is_archived(_other) do
    false
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
