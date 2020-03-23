defmodule Vega.BoardList do
  @moduledoc false

  alias Vega.BoardList
  alias Vega.Card

  defstruct [:_id, :id, :pos, :title, :cards]

  def new(title, pos) do
    %BoardList{_id: Mongo.object_id(), title: title, pos: pos}
  end

  def to_struct(%{"_id" => id, "title" => title, "pos" => pos} = list) do
    %BoardList{_id: id, pos: pos, title: title, cards: Card.fetch_all_in_list(id) |> Enum.sort({:asc, Card})}
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
