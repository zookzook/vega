defmodule Vega.Card do
  @moduledoc """

  This module describes a card struct. A card is a basic data structure, which contains a lot of interesting details
  of a card.

  """

  alias Vega.Card

  @collection "cards"

  defstruct [:_id, :created, :pos, :modified, :title, :description, :board, :list]

  def new(board, list, user, title, pos) do
    %Card{_id: Mongo.object_id(),
      title: title,
      board: board._id,
      list: list._id,
      created: DateTime.utc_now(),
      modified: DateTime.utc_now(),
      pos: pos}
  end

  def fetch_all_in_list(id) do
    Mongo.find(:mongo, @collection, %{list: id}) |> Enum.map(fn card -> to_struct(card) end)
  end

  def to_struct(card) do
    %Card{_id: card["_id"],
      title: card["title"],
      board: card["board"],
      list: card["list"],
      created: card["created"],
      modified: card["modified"],
      pos: card["pos"]}
  end

  #@spec compare(Calendar.date(), Calendar.date()) :: :lt | :eq | :gt
  def compare(a, b) do
    case a.pos - b.pos do
      x when x < 0 -> :lt
      x when x > 0 -> :gt
      _            -> :eq
    end
  end
  

end
