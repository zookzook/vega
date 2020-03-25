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

  defstruct [
    :_id,       ## the id
    :ts,        ## timestamp
    :modified,  ## last modification date
    :author_id, ## id of the user
    :t,         ## the type of modification
    :board,     ## the id of the board
    :list,      ## the id of the list
    :keys,      ## keys for gettext
    :msg        ## the localized message of the modification
  ]

  @collection "issues"

  def new(type, %User{_id: author_id}) do
    %Issue{_id: Mongo.object_id(), author_id: author_id, ts: DateTime.utc_now(), t: type}
  end
  def new(type, %User{_id: author_id}, %Board{_id: board}) do
    %Issue{_id: Mongo.object_id(), author_id: author_id, ts: DateTime.utc_now(), t: type, board: board}
  end
  def new(type, %User{_id: author_id}, %Board{_id: board}, %BoardList{_id: list}) do
    %Issue{_id: Mongo.object_id(), author_id: author_id, ts: DateTime.utc_now(), t: type, board: board, list: list}
  end

  @doc """
  Add keys to the issue which are used to format a localized string in the history view of the app.
  """
  def add_message_keys(issue, keys \\ []) do
    %Issue{issue | keys: keys}
  end

  def author(%Issue{author_id: author_id}) do
    User.fetch(author_id) ## todo caching system
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