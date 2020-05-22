defmodule Vega.Issue do

  @moduledoc """
  The issue contains the details of the history of all modifications. For each modification an issue document
  is created to record all details and references that belong to the modification.

  At the front end a human friendly message is rendered: The field `:msg` contains the text of the modification while
  the field `:keys` contains the relevant information as a simple map structure, which is used to build the text of
  the modification with the help of `Gettext` to localize the message. This is done in function `Issues.to_struct/1`.

  """

  alias Vega.Issue
  alias Vega.Issues
  alias Vega.User
  alias Vega.Board
  alias Vega.BoardList
  alias Yildun.Collection

  use Collection

  @collection "issues"

  collection "issues" do
    attribute :ts, DateTime.t() , default: &DateTime.utc_now/0  ## timestamp
    attribute :author_id, BSON.ObjectId.t()                     ## id of the user
    attribute :t, non_neg_integer()                             ## the type of modification see Vega.IssueConsts
    attribute :board, BSON.ObjectId.t()                         ## the id of the board
    attribute :list, BSON.ObjectId.t()                          ## the id of the list
    attribute :keys, map()                                      ## keys for gettext
    attribute :msg, String.t()                                  ## the localized message of the modification

    after_load &Issue.after_load/1
  end

  def new(type, %User{_id: author_id}) do
    %Issue{new() | author_id: author_id, t: type}
  end
  def new(type, %User{_id: author_id}, %Board{_id: board}) do
    %Issue{new() | author_id: author_id, t: type, board: board}
  end
  def new(type, %User{_id: author_id}, %Board{_id: board}, %BoardList{_id: list}) do
    %Issue{new() | author_id: author_id, t: type, board: board, list: list}
  end

  @doc """
  Add keys to the issue which are used to format a localized string in the history view of the app.
  """
  def add_message_keys(issue, keys \\ []) do
    %Issue{issue | keys: keys}
  end

  def author(%Issue{author_id: author_id}) do
    User.get(author_id)
  end

  def fetch_all(nil) do
    []
  end
  def fetch_all(%Board{_id: id}) do
    Mongo.find(:mongo, @collection, %{"board" => id}, sort: %{ts: -1}, limit: 5) |> Enum.map(fn issue -> issue |> load() end)
  end
  def fetch_all_raw(%Board{_id: id}) do
    Mongo.find(:mongo, @collection, %{"board" => id})
  end

  def after_load(%Issue{keys: keys} = issue) when keys == nil do
    Issues.add_message(%Issue{issue | keys: []})
  end
  def after_load(issue) do
    Issues.add_message(issue)
  end

  def check() do
    case Mongo.show_collections(:mongo) |> Enum.any?(fn coll -> coll == @collection end) do
      false -> Mongo.create(:mongo, @collection)
      true  -> :ok
    end
  end

  def clone_issues(issues, board, mapping) do
    Enum.map(issues, fn issue -> clone(issue, board, Map.get(mapping, issue["list"])) end)
  end

  def clone(%{"list" => list} = issue, board, list) do
    %{issue | "_id" => Mongo.object_id(), "board" => board, "list" => list}
  end
  def clone(issue, board, _list) do
    %{issue | "_id" => Mongo.object_id(), "board" => board}
  end
end