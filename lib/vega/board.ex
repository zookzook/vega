defmodule Vega.Board do
  @moduledoc """

  This module describes a board struct.

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

  defstruct [:_id, :created, :modified, :title, :description, :members, :lists]

  def new(title, %User{_id: id}) do

    members = %{"admin" => id}
    board = %Board{_id: Mongo.object_id(), title: title, created: DateTime.utc_now(), modified: DateTime.utc_now(), members: members}
    with {:ok, _} <- Mongo.insert_one(:mongo, @collection, to_map(board)) do
      fetch(board)
    end
  end

  @doc """
  Delete a board with all isses and cards attached to the board
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
  Set the title of the board. It creates an issue for the historie and returns the new board
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

    ordering = length(lists)
    column   = title |> BoardList.new(ordering) |> to_map()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$push" => %{"lists" => column}}, trans) do
        :ok
      end
    end, true)
  end

  @doc"""
  Delete a list from the board. The ordering attribute of the left lists are new calculated.
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

    bulk = Enum.reduce(other_lists, bulk, fn {list_id, index}, bulk -> UnorderedBulk.update_one(bulk, %{_id: id, "lists._id": list_id}, %{"$set" => %{"lists.$.ordering" => index}}) end)

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

    bulk = Enum.reduce(other_lists, UnorderedBulk.new(@collection), fn {list_id, index}, bulk -> UnorderedBulk.update_one(bulk, %{_id: id, "lists._id": list_id}, %{"$set" => %{"lists.$.ordering" => index}}) end)

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
           |> Enum.with_index(1.0)
           |> Enum.reduce(bulk, fn {card_id, pos}, bulk -> UnorderedBulk.update_one(bulk, %{_id: card_id}, %{"$set" => %{"pos" => pos}}) end)

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
      %Card{pos: pos} -> pos + 1.0
      nil             -> 1.0
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
    add_cards_pos(board, list, user, xs, pos + 1.0)
  end

  @doc """
  Move a card after a card within a list and preserve the order of the cards.
  """
  def move_card_after(user, board, card, after_card) do
    board
  end

  @doc """
  Move a card before a card within the cards list and preserve the order of the cards.
  * `cards` the list of cards
  * `card_id` the id of the card to be moved to before the card with the id `before_id`
  * `before_id` the id of the card where the other card should moved in front of it

  As the result the new board is returned.
  """
  def move_card_before(user, board, %BoardList{_id: id, cards: cards}, card_id, before_id) do

    with pos <- calc_new_pos_before(cards, before_id) do

      issue = id
              |> MoveCard.new()
              |> Issue.new(user, board)
              |> to_map()

      with_transaction(board, fn trans ->
         with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
              {:ok, _} <- Mongo.update_one(:mongo, @cards_collection, %{_id: card_id}, %{"$set" => %{"pos" => pos}}) do
           :ok
         end
      end, true)
    end
  end

  defp calc_new_pos_before([], _id) do
    1.0
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
  Move a card after a card within another list and preserve the order of the cards.
  """
  def move_card_after(user, board, list, card, after_card) do
    board
  end

  @doc """
  Move a card before a card within another list and preserve the order of the cards.
  """
  def move_card_before(user, board, list, card, before_card) do
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
      lists: lists |> Enum.sort(fn (a,b) -> a.ordering <= b.ordering end)}
  end
end
