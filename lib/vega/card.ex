defmodule Vega.Card do
  @moduledoc """

  This module describes a card struct. A card is a basic data structure, which contains a lot of interesting details
  of a card.

  """

  use Yildun.Collection

  alias Vega.Card
  alias Vega.Comment

  @collection "cards"

  collection "cards" do
    attribute :id, String.t(), derived: true                          ## the ObjectId as string
    attribute :created, DateTime.t(), default: &DateTime.utc_now/0    ## creation date
    attribute :modified, DateTime.t(), default: &DateTime.utc_now/0   ## last modification date
    attribute :title, String.t()                                      ## the title of the card
    attribute :description, String.t()                                ## optional: a description as Markdown
    attribute :pos, float()                                           ## current position for ordering
    attribute :board, BSON.ObjectId.t()                               ## the id of the board
    attribute :list, BSON.ObjectId.t()                                ## the id of the list
    attribute :archived, DateTime.t()                                 ## date of the archiving
    embeds_many :comments, Comment, default: []                       ## list of comments

    after_load  &Card.after_load/1
  end

  @doc """
  Create a new card with a title `title` and position `pos`.
  """
  def new(board, list, title, pos) do
    %Card{_id: id} = card = new()
    %Card{card | id: BSON.ObjectId.encode!(id), title: title, board: board._id, list: list._id, pos: pos}
  end
  @doc """
  Create a new card with a title `title`, position `pos` and `time`. This funcation is used, when a sequence of
  cards is created to preserve the order of creating time.
  """
  def new(board, list, title, pos, time) do
    %Card{_id: id} = card = new()
    %Card{card | id: BSON.ObjectId.encode!(id),
      title: title,
      board: board._id,
      list: list._id,
      pos: pos,
      created: time,
      modified: time}
  end


  @doc """
  Deep copy of the card
  """
  def clone(board, list, card) do
    id = Mongo.object_id()
    %Card{card | _id: id,
      id: BSON.ObjectId.encode!(id),
      board: board.id,
      list: list._id}
  end

  @doc """
  Fetch all cards of the list with id `id`.
  """
  def fetch_all_in_list(id) do
    Mongo.find(:mongo, @collection, %{list: id, archived: %{"$exists": false}}) |> Enum.map(fn card -> load(card) end)
  end

  @doc """
  Post-Processing after loading the struct from the database.
  """
  def after_load(%Card{_id: id, comments: comments} = card) when comments == nil do
    %Card{card | id: BSON.ObjectId.encode!(id), comments: []}
  end
  def after_load(%Card{_id: id, comments: comments} = card) do
    %Card{card | id: BSON.ObjectId.encode!(id), comments: Enum.reverse(comments)}
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
