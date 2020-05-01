defmodule Vega.Card do
  @moduledoc """

  This module describes a card struct. A card is a basic data structure, which contains a lot of interesting details
  of a card.

  """

  import Vega.StructHelper

  alias Vega.Card
  alias Vega.Comment

  @collection "cards"

  @derived_attributes [:id]

  defstruct [
    :_id,         ## the ObjectId of the card
    :id,          ## the ObjectId as string
    :created,     ## creation date
    :pos,         ## current position for ordering
    :modified,    ## last modification date
    :title,       ## the title of the card
    :description,     ## optional: a description as Markdown
    :board,           ## the id of the board
    :list,            ## the id of the list
    :archived,        ## date of the archiving
    :comments         ## list of comments
  ]

  @doc """
  Create a new card with a title `title` and position `pos`.
  """
  def new(board, list, title, pos) do
    id = Mongo.object_id()
    %Card{_id: id,
      id: BSON.ObjectId.encode!(id),
      title: title,
      board: board._id,
      list: list._id,
      created: DateTime.utc_now(),
      modified: DateTime.utc_now(),
      pos: pos}
  end
  @doc """
  Create a new card with a title `title`, position `pos` and `time`. This funcation is used, when a sequence of
  cards is created to preserve the order of creating time.
  """
  def new(board, list, title, pos, time) do
    id = Mongo.object_id()
    %Card{_id: Mongo.object_id(),
      id: BSON.ObjectId.encode!(id),
      title: title,
      board: board._id,
      list: list._id,
      created: time,
      modified: time,
      pos: pos}
  end


  @doc """
  Deep copy of the card
  """
  def clone(board, list, card) do
    id = Mongo.object_id()
    %Card{card | _id: id, id: BSON.ObjectId.encode!(id), board: board.id, list: list._id}
  end

  @doc """
  Fetch all cards of the list with id `id`.
  """
  def fetch_all_in_list(id) do
    Mongo.find(:mongo, @collection, %{list: id, archived: %{"$exists": false}}) |> Enum.map(fn card -> load(card) end)
  end

  def dump(%Card{} = card) do
    card
    |> Map.drop(@derived_attributes)
    |> to_map()
  end

  @doc """
  Convert a map structure to Card-struct.
  """
  def load(card) do

    %Card{_id: card["_id"],
      id: BSON.ObjectId.encode!(card["_id"]),
      title: card["title"],
      board: card["board"],
      list: card["list"],
      created: card["created"],
      modified: card["modified"],
      pos: card["pos"],
      archived: card["archived"],
      comments: (card["comments"] || []) |> Enum.map(fn m -> Comment.load(m) end) |> Enum.reverse()
    }
  end

  def is_archived(%Card{archived: date}) do
    date != nil
  end

  #@spec compare(Calendar.date(), Calendar.date()) :: :lt | :eq | :gt
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
