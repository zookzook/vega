defmodule Vega.BoardList do
  @moduledoc false

  alias Vega.BoardList
  alias Vega.Card

  defstruct [:_id, :id, :ordering, :title, :cards]

  def new(title, ordering) do
    %BoardList{_id: Mongo.object_id(), title: title, ordering: ordering}
  end

  def to_struct(%{"_id" => id, "title" => title, "ordering" => ordering} = list) do
    %BoardList{_id: id, ordering: ordering, title: title, cards: Card.fetch_all_in_list(id) |> Enum.sort({:asc, Card})}
  end

end
