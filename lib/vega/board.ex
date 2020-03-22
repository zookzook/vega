defmodule Vega.Board do
  @moduledoc """

  This module describes a board struct. It is the root of a tree. It contains a lists of `BoardList` structs. Each
  `BoardList` contains a list of cards. The card is the basic struct which contains the real data. Lists and boards
  are used to organize and to group the cards.

  Each modification is recorded as an `Issue`, which contains all information that changed. So, we have three
  collections in the MongoDB:

  1) boards
  2) cards
  3) issues

  Since a list or a card can be archived, there exists for lists and cards a collection for the archived documents:

  1) archived_cards
  2) archived_lists

  The goal of these two collection is better performace by keeping the other collections smaller. If a card is going
  to get archived it will be moved from the collection `cards` to collection `archived`.

  """

  import Vega.StructHelper

  alias Vega.Board
  alias Mongo.Session
  alias Vega.Issue
  alias Vega.Card
  alias Vega.BoardList
  alias Vega.Issue.AddList
  alias Vega.Issue.DeleteList
  alias Vega.Issue.NewCard
  alias Vega.Issue.SetDescription
  alias Vega.Issue.SetTitle
  alias Vega.Issue.ReorderList
  alias Vega.Issue.SortCards
  alias Vega.Issue.MoveCard
  alias Vega.User
  alias Mongo.UnorderedBulk
  alias Mongo.BulkWrite

  @collection         "boards"
  @issues_collection  "issues"
  @cards_collection   "cards"

  ##
  # Since we support user ordered list, we save the current ordering by using the attribute `:pos`, which is
  # a float number. The cards are sorted using this attribute. We define a gap between the cards and a starting
  # position.
  #
  # Example: assume we have a list of cards in this order: [a, b, c]. Then we have the following positions:
  # [100.0, 200.0, 300.0]
  #
  # By moving a card to another position, we will calculate the position by using the neighbours pre and next:
  #
  # :pos = pre.pos + (next.pos - prev.pos) / 2
  #
  # If we move c in front of b, we get the new position (simplified version):
  #
  # 100.0 + (200.0 - 100.0) / 2 = 100.0 + 50 = 150.0
  #
  # We are using a gap of 100.0 only for better debugging, because we can use a gap of 1.0 as well.
  #
  # In case of sorting by date or title, the position will be recalculated by using the `@pos_start`
  # and `@pos_gap` constants.
  #
  @pos_gap   100.0
  @pos_start 100.0

  defstruct [:_id, :created, :modified, :title, :description, :members, :lists]

  @doc """
  Create a new empty board.
  """
  def new(title, %User{_id: id}) do

    members = %{"admin" => id}
    board = %Board{_id: Mongo.object_id(), title: title, created: DateTime.utc_now(), modified: DateTime.utc_now(), members: members}
    with {:ok, _} <- Mongo.insert_one(:mongo, @collection, to_map(board)) do
      fetch(board)
    end
  end

  @doc """
  Delete a board with all isses and cards attached to the board.

  todo: cleanup the archived-collections as well
  """
  def delete(%Board{_id: id}) do

    with {:ok, n_issues, n_cards} <- Session.with_transaction(:mongo, fn trans ->
      with {:ok, %Mongo.DeleteResult{deleted_count: n_issues}} <- Mongo.delete_many(:mongo, @issues_collection, %{board: id}, trans),
           {:ok, %Mongo.DeleteResult{deleted_count: n_cards}} <- Mongo.delete_many(:mongo, @cards_collection, %{board: id}, trans),
           {:ok, _} <- Mongo.delete_one(:mongo, @collection, %{_id: id}, trans) do
        {:ok, n_issues, n_cards}
      end
    end) do
      {:ok, n_issues, n_cards}
    end

  end

  @doc """
  Set the title of the board. It creates an issue `Vega.Issue.SetTitle` for the history and returns the new board.

  ## Example

    board = Board.set_title(board, user, "New title")
  """
  def set_title(%Board{_id: id} = board, user, title) do

    issue = title
            |> SetTitle.new()
            |> Issue.new(user, board)
            |> to_map()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$set" => %{"title" => title}}, trans) do
        :ok
      end
    end)
  end

  @doc """
  Set the description of the board. It creates an issue for the historie and returns the new board
  """
  def set_description(%Board{_id: id} = board, user, description) do

    issue = description
            |> SetDescription.new()
            |> Issue.new(user, board)
            |> to_map()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$set" => %{"description" => description}}, trans) do
        :ok
      end
    end)

  end

  def add_list(%Board{_id: id, lists: lists} = board, user, title) do
    issue = title
            |> AddList.new()
            |> Issue.new(user, board)
            |> to_map()

    pos     = length(lists)
    column  = title |> BoardList.new(pos) |> to_map()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$push" => %{"lists" => column}}, trans) do
        :ok
      end
    end, true)
  end

  @doc"""
  Delete a list from the board. The pos attribute of the left lists are new calculated.
  """
  def delete_list(%Board{_id: id, lists: lists} = board, user, %BoardList{_id: list_id, title: title}) do

    issue = title
            |> DeleteList.new()
            |> Issue.new(user, board)
            |> to_map()

    other_lists = lists
                  |> Enum.reject(fn l -> l._id == list_id end)
                  |> Enum.with_index()
                  |> Enum.map(fn {l, index} -> {l._id, index} end)

    bulk = @collection
           |> UnorderedBulk.new()
           |> UnorderedBulk.update_one(%{_id: id}, %{"$pull" => %{"lists" => %{"_id" => list_id}}})

    bulk = Enum.reduce(other_lists, bulk, fn {list_id, index}, bulk -> UnorderedBulk.update_one(bulk, %{_id: id, "lists._id": list_id}, %{"$set" => %{"lists.$.pos" => index}}) end)

    with_transaction(board, fn trans ->
     with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
          %Mongo.BulkWriteResult{} <- BulkWrite.write(:mongo, bulk, trans) do
       :ok
     end
    end, true)
  end

  def reorder_list(%Board{_id: id} = board, user, new_lists) do

    issue = new_lists
            |> Enum.map(fn %BoardList{title: title} -> title end)
            |> ReorderList.new()
            |> Issue.new(user, board)
            |> to_map()

    other_lists = new_lists
                  |> Enum.with_index()
                  |> Enum.map(fn {l, index} -> {l._id, index} end)

    bulk = Enum.reduce(other_lists, UnorderedBulk.new(@collection), fn {list_id, index}, bulk -> UnorderedBulk.update_one(bulk, %{_id: id, "lists._id": list_id}, %{"$set" => %{"lists.$.pos" => index}}) end)

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
          %Mongo.BulkWriteResult{} <- BulkWrite.write(:mongo, bulk, trans) do
       :ok
      end
    end, true)
  end

  @doc """
  Reorders the list of cards. `cards` is ordered and contains only the IDs of the card.
  """
  def sort_cards(board, user, cards) do

    issue = "asc"
            |> SortCards.new()
            |> Issue.new(user, board)
            |> to_map()

    bulk = UnorderedBulk.new(@cards_collection)
    bulk = cards
           |> Enum.with_index(1)
           |> Enum.reduce(bulk, fn {card_id, pos}, bulk -> UnorderedBulk.update_one(bulk, %{_id: card_id}, %{"$set" => %{"pos" => pos * @pos_gap}}) end)

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
          %Mongo.BulkWriteResult{} <- BulkWrite.write(:mongo, bulk, trans) do
       :ok
      end
    end, true)

  end

  def add_card(board, list, user, title, fetch_result \\ true) do

    issue = title
            |> NewCard.new()
            |> Issue.new(user, board)
            |> to_map()

    pos = calc_pos(list)
    card = board |> Card.new(list, user, title, pos) |> to_map()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.insert_one(:mongo, @cards_collection, card, trans) do
        :ok
      end
    end, fetch_result)

  end

  ##
  # In case we are adding a list of new cards, we will return the last position. In this case we
  # can calculate the new position by the result of the previous inserting. That is much faster than
  # traveling to the last card to read the position.
  ##
  defp add_card_pos(board, list, user, title, pos) do

    issue = title
            |> NewCard.new()
            |> Issue.new(user, board)
            |> to_map()

    pos = pos || calc_pos(list)
    card = board |> Card.new(list, user, title, pos) |> to_map()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
          {:ok, _} <- Mongo.insert_one(:mongo, @cards_collection, card, trans) do
       :ok
      end
    end, false)

    pos
  end

  defp calc_pos(%BoardList{cards: cards}) do
    case List.last(cards) do
      %Card{pos: pos} -> pos + @pos_gap
      nil             -> @pos_start
    end
  end

  @doc """
  Creates from a list of title new cards and adds them to the list. For each card a new position is calculated to
  preserve the order. We are using the special function `add_card_pos` that returns the last position to calculate
  the next position for the next new card.
  """
  def add_cards(board, _list, _user, []) do
    board
  end
  def add_cards(board, list, user, [title]) do
    add_card(board, list, user, title, true)
  end
  def add_cards(board, list, user, titles) do
    add_cards_pos(board, list, user, titles, nil)
  end
  defp add_cards_pos(board, list, user, [title], pos) do
    _pos = add_card_pos(board, list, user, title, pos)
    fetch(board)
  end
  defp add_cards_pos(board, list, user, [title|xs], pos) do
    pos = add_card_pos(board, list, user, title, pos)
    add_cards_pos(board, list, user, xs, pos + @pos_gap)
  end


  @doc """
  Move a card before a card within the cards list and preserve the order of the cards.
  * `cards` the list of cards
  * `card_id` the id of the card to be moved to before the card with the id `before_id`
  * `before_id` the id of the card where the other card should moved in front of it

  As the result the new board is returned.
  """
  def move_card_before(user, board, %BoardList{_id: id, cards: cards}, card, before_card) do

    with pos <- calc_new_pos_before(cards, before_card._id) do

      issue = id
              |> MoveCard.new()
              |> Issue.new(user, board)
              |> to_map()

      with_transaction(board, fn trans ->
         with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
              {:ok, _} <- Mongo.update_one(:mongo, @cards_collection, %{_id: card._id}, %{"$set" => %{"pos" => pos}}) do
           :ok
         end
      end, true)
    end
  end

  defp calc_new_pos_before([], _id) do
    @pos_start
  end
  defp calc_new_pos_before([card], id) do
    case card._id == id do
      true  -> card.pos / 2
      false -> 0.0
    end
  end
  defp calc_new_pos_before([pre, next | xs], id) do
    case pre._id == id do
      true  -> pre.pos / 2
      false ->
        case next._id == id do
          true -> pre.pos + (next.pos - pre.pos) / 2
          false -> calc_new_pos_before([next | xs], id)
        end
    end
  end

  @doc """
  Move a card after to the end of all cards and preserve the order of the cards.
  """
  def move_card_to_end(user, board, list, card, after_card) do
    board
  end

  @doc """
  Get the list from the board. The usual case is that the board was
  modified and a new version was fetched from the database. Now we
  need the updated version of the list.
  """
  def find_list(board, %BoardList{_id: list_id}) do
    find_list(board, list_id)
  end
  def find_list(%Board{lists: lists}, list_id) do
    Enum.find(lists, fn %BoardList{_id: id} -> id == list_id end)
  end

  @doc """
  Execute the funcation by using the transaction api of the MongoDB. In case
  of an error the changes are roll backed.
  """
  def with_transaction(board, fun, fetch_result \\ true)
  def with_transaction(board, fun, true) do
    with {:ok, :ok} <- Session.with_transaction(:mongo, fn trans ->
      with :ok <- fun.(trans), do: {:ok, :ok}
    end), do: fetch(board)
  end
  def with_transaction(board, fun, false) do
    with {:ok, :ok} <- Session.with_transaction(:mongo, fn trans ->
     with :ok <- fun.(trans), do: {:ok, :ok}
    end), do: board
  end

  def fetch_one() do
    :mongo
    |> Mongo.find_one(@collection, %{})
    |> to_struct()
  end
  def fetch(%Board{_id: id}) do
    :mongo
    |> Mongo.find_one(@collection, %{_id: id})
    |> to_struct()
  end
  def fetch(id) do
    :mongo
    |> Mongo.find_one(@collection, %{_id: BSON.ObjectId.decode!(id)})
    |> to_struct()
  end

  @doc """
  Convert a map structure to a `Board` struct. The function fills the each list with
  the connected cards. The lists and cards are sorted according the position attribute.
  """
  def to_struct(nil) do
    nil
  end
  def to_struct(board) do

    lists = (board["lists"] || [])  |> Enum.map(fn list-> BoardList.to_struct(list) end)

    %Board{_id: board["_id"],
      created: board["created"],
      modified: board["modified"],
      title: board["title"],
      members: board["members"],
      lists: lists |> Enum.sort({:asc, BoardList})}
  end
end
