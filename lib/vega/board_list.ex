defmodule Vega.BoardList do
  @moduledoc false

  use Yildun.Collection

  alias Vega.BoardList
  alias Vega.Card
  alias Vega.WarningColorRule
  alias Mongo.UnorderedBulk

  @cards_collection "cards"

  document do
    attribute :_id, BJSON.ObjectId.t(), default: &Mongo.object_id()/0      ## the ObjectId of the list
    attribute :id, String.t(), derived: true                               ## derived, the ObjectId as a string
    attribute :created, DateTime.t(), default: &DateTime.utc_now/0         ## creation date
    attribute :modified, DateTime.t(), default: &DateTime.utc_now/0        ## last modification date
    attribute :archived, DateTime.t()                                      ## archiving date
    attribute :pos, float()                                                ## current pos
    attribute :title, String.t()                                           ## the title
    attribute :cards, list(Card.t()), derived: true                        ## the cards (fetched)
    attribute :n_cards, non_neg_integer(), derived: true                   ## the number of cards (derived)
    embeds_one :color, WarningColorRule                                    ## the color rule of the list

    after_load  &BoardList.after_load/1
  end

  def new(title, pos) do
    %BoardList{_id: id} = list = new()
    %BoardList{list |
      title: title,
      pos: pos,
      id: BSON.ObjectId.encode!(id)
      }
  end

  @doc """
  Create a deep copy. The result is a tuple with the new list and an unordered bulk operation for the cards to insert.
  """
  def clone(board, %BoardList{cards: cards} = list) do
    result = %BoardList{list | _id: Mongo.object_id, cards: nil, n_cards: nil }
    bulk = UnorderedBulk.new(@cards_collection)
    bulk = Enum.reduce(cards, bulk, fn card, bulk -> UnorderedBulk.insert_one(bulk, Card.clone(board, result, card) |> Yildun.Collection.dump()) end)
    {list._id, result, bulk}
  end

  def after_load(%BoardList{_id: id} = list) do
    cards = Card.fetch_all_in_list(id) |> Enum.sort({:asc, Card})

    %BoardList{ list |
      cards: cards,
      id: BSON.ObjectId.encode!(id),
      n_cards: length(cards)
    }
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
