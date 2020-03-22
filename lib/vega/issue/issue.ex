defmodule Vega.Issue do

  alias Vega.Issue
  alias Vega.Issues
  alias Vega.User
  alias Vega.Board
  alias Vega.BoardList

  defstruct [:_id, :ts, :modified, :author_id, :t, :board, :list]

  @collection "issues"

  def new(type, %User{_id: author_id}) do
    %Issue{_id: Mongo.object_id(), author_id: author_id, ts: DateTime.utc_now(), t: type}
  end
  def new(type, %User{_id: author_id}, %Board{_id: board}) do
    %Issue{_id: Mongo.object_id(), author_id: author_id, ts: DateTime.utc_now(), t: type, board: board}
  end

  def fetch_all(nil) do
    []
  end
  def fetch_all(%Board{_id: id}) do
    Mongo.find(:mongo, @collection, %{"board" => id}, sort: %{ts: -1}, limit: 5) |> Enum.map(fn issue -> Issues.to_struct(issue) end)
  end

  def check() do
    case Mongo.show_collections(:mongo) |> Enum.any?(fn coll -> coll == @collection end) do
      false -> Mongo.create(:mongo, @collection)
      true  -> :ok
    end
  end
end