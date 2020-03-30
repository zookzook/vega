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

  alias Mongo.BulkWrite
  alias Mongo.Session
  alias Mongo.UnorderedBulk
  alias Vega.Board
  alias Vega.BoardList
  alias Vega.Card
  alias Vega.Issue
  alias Vega.IssueConsts
  alias Vega.User

  @new_board       IssueConsts.encode(:new_board)
  @new_card        IssueConsts.encode(:new_card)
  @set_description IssueConsts.encode(:set_description)
  # todo: @add_comment     IssueConsts.encode(:add_comment)
  @set_title       IssueConsts.encode(:set_title)
  @add_list        IssueConsts.encode(:add_list)
  @delete_list     IssueConsts.encode(:delete_list)
  @sort_cards      IssueConsts.encode(:sort_cards)
  @move_card       IssueConsts.encode(:move_card)
  @move_list       IssueConsts.encode(:move_list)

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

  defstruct [
    :_id,         ## the ObjectId of the board
    :options,     ## options for styling etc.
    :id,          ## the ObjectId as string
    :created,     ## the creation date
    :modified,    ## the last modification date
    :title,       ## the title
    :description, ## optional: the description
    :members,     ## the list of members of the board
    :lists        ## the lists of the board
  ]

  @doc """
  Create a new empty board with the `title`.

  ## Example
      iex> Vega.Board.new(user, "My first Board")

  """
  def new(%User{_id: id} = user, title, opts) do
    members = %{"role" => "admin", "id" => id}
    board   = %Board{
      _id: Mongo.object_id(),
      title: title,
      created: DateTime.utc_now(),
      modified: DateTime.utc_now(),
      members: members,
      options: opts
    }

    issue = @new_board
            |> Issue.new(user, board)
            |> Issue.add_message_keys(title: title, board: board.title)
            |> to_map()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.insert_one(:mongo, @collection, to_map(board), trans)  do
        :ok
      end
    end)
  end

  @doc """
  Delete a board with all isses and cards attached to that board.
  ## Example

    iex> {:ok, issue, cards} = Vega.Board.delete(board)

  """
  def delete(%Board{_id: id}) do

    ## todo: cleanup the archived-collections as well
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

    iex> Vega.Board.set_title(board, user, "New title")

  """
  def set_title(%Board{_id: id} = board, user, title) do

    issue = @set_title
            |> Issue.new(user, board)
            |> Issue.add_message_keys(title: title, board: board.title)
            |> to_map()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$set" => %{"title" => title}}, trans) do
        :ok
      end
    end)
  end

  @doc """
  Set the description of the board. It creates an issue `Vega.Issue.SetDescription` for the history and returns the new board.

  ## Example

    iex> Vega.Board.set_description(board, user, "## Welcome ##")

  """
  def set_description(%Board{_id: id} = board, user, description) do

    issue = @set_description
            |> Issue.new(user, board)
            |> Issue.add_message_keys(description: description, board: board.title)
            |> to_map()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$set" => %{"description" => description}}, trans) do
        :ok
      end
    end)

  end

  @doc """
  Add a new list to the board. It creates an issue `Vega.Issue.AddList` for the history and returns the new board.

  ## Example

    iex> Vega.Board.add_list(board, user, "To do")

  """
  def add_list(%Board{_id: id, title: board_title} = board, user, title) do

    issue = @add_list
            |> Issue.new(user, board)
            |> Issue.add_message_keys(title: title, board: board_title)
            |> to_map()

    pos     = calc_pos(board)
    column  = title |> BoardList.new(pos) |> to_map()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$push" => %{"lists" => column}}, trans) do
        :ok
      end
    end)
  end

  @doc"""
  Delete a list from the board and all cards attached to this list.

  ## Example

    iex> Vega.Board.delet_list(board, user, list)
  """
  def delete_list(%Board{_id: id} = board, user, %BoardList{_id: list_id, title: title}) do

    issue = @delete_list
            |> Issue.new(user, board)
            |> Issue.add_message_keys(a: title, board: board.title)
            |> to_map()

    with_transaction(board, fn trans ->
     with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
          {:ok, _} <- Mongo.delete_many(:mongo, @cards_collection, %{list: id}, trans),
          {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$pull" => %{"lists" => %{"_id" => list_id}}}, trans) do
       :ok
     end
    end)

  end

  @doc """
  Move a list before another list within the board and preserve the order of the lists.
  * `lists` the list of lists
  * `list_id` the id of the card to be moved to before the card with the id `before_id`
  * `before_id` the id of the card where the other card should moved in front of it

  As the result the new board is returned.
  """
  def move_list_before(%Board{_id: id, lists: lists} = board, user, list, before_list) do

    with pos <- calc_new_pos_before(lists, before_list._id) do

      issue = @move_list
              |> Issue.new(user, board)
              |> Issue.add_message_keys(a: list.title, b: before_list.title)
              |> to_map()

      with_transaction(board, fn trans ->
        with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
             {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id, "lists._id": list._id}, %{"$set" => %{"lists.$.pos" => pos}}) do
          :ok
        end
      end)
    end
  end

  @doc """
  Move a list after to the end of all lists and preserve the order of the cards. It create a `MoveList` issue.
  If 'lists' of the board is empty, then the position is `@pos_start` otherwise the position is `last.pos + @pos_gap`

  * `user` current user
  * `board` current board
  * `list` the list to be moved to the end of the lists

  It returns the new board.

  """
  def move_list_to_end(%Board{_id: id} = board, user, list) do

    pos   = calc_pos(board)
    issue = @move_list
            |> Issue.new(user, board)
            |> Issue.add_message_keys(a: list.title)
            |> to_map()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id, "lists._id": list._id}, %{"$set" => %{"lists.$.pos" => pos}}) do
        :ok
      end
    end)
  end

  @doc """
  Reorders the list of cards. `cards` are ordered and reflect the new order.
  It creates an issue `Vega.Issue.SortCards` for the history and returns the new board. The `:pos` attribute
  contains the new position of each card. It starts with the value of `@pos_start` and uses for the next positions
  a gap of `@pos_gap`.

  ## Example

    iex> [a] = board.lists
    iex> cards = Enum.sort(a.cards, fn left, right -> left.title >= right.title end)
    iex> board = Vega.Board.sort_cards(board, user, cards, "asc")

  """
  def sort_cards(board, user, cards, type) do

    issue = @sort_cards
            |> Issue.new(user, board)
            |> Issue.add_message_keys(type: type)
            |> to_map()

    bulk = UnorderedBulk.new(@cards_collection)
    bulk = cards
           |> Enum.with_index(1)
           |> Enum.reduce(bulk, fn {%Card{_id: card_id}, pos}, bulk -> UnorderedBulk.update_one(bulk, %{_id: card_id}, %{"$set" => %{"pos" => pos * @pos_gap}}) end)

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
          %Mongo.BulkWriteResult{} <- BulkWrite.write(:mongo, bulk, trans) do
       :ok
      end
    end)

  end

  @doc"""
  Add a new card with the `title` to the list `list`. It creates an issue `Vega.Issue.NewCard` for the history and returns the new board. The `:pos` attribute
  contains the new position of new card. It uses the position of the last card and adds the value of `@pos_gap` to it. If the list is empty, than the position is
  `@pos_start`.

  ## Example

    iex> Vega.Board.add_card(board, user, list, "The new card")

  """
  def add_card(board, user, list, title) do

    issue = @new_card
            |> Issue.new(user, board)
            |> Issue.add_message_keys(title: title, list: list.title)
            |> to_map()

    pos = calc_pos(list)
    card = board |> Card.new(list, title, pos) |> to_map()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.insert_one(:mongo, @cards_collection, card, trans) do
        :ok
      end
    end)

  end

  @doc """
  Creates from a list of title new cards and adds them to the list. For each card a new position is calculated to
  preserve the order. We are using the special function `add_card_pos` that returns the last position to calculate
  the next position for the next new card.

  The creation and modification date use a time gap of one millisecond to preserve the order.

  ## Example

    iex> new_titles = ["this", "is", "a", "test"]
    iex> board  = Board.add_cards(board, user, list, new_titles)

  """
  def add_cards(board, _user, _list, []) do
    board
  end
  def add_cards(board, user, list, [title]) do
    add_card(board, user, list, title)
  end
  def add_cards(board, user, list, titles) do

    time       = DateTime.utc_now()
    pos        = calc_pos(list)
    issue_bulk = UnorderedBulk.new(@issues_collection)
    card_bulk  = UnorderedBulk.new(@cards_collection)

    # we are creating two bulks: one for issues and one for the cards
    {{issue_bulk, card_bulk}, {_pos, _time}} = Enum.reduce(titles, {{issue_bulk, card_bulk}, {pos, time}},
      fn title, {{i_bulk, c_bulk}, {p, t}} -> {make_insert_card_operation({i_bulk, c_bulk}, board, user, list, title, p, t), {p + @pos_gap, DateTime.add(t, 1, :millisecond)}} end)

    with_transaction(board, fn trans ->

      with %Mongo.BulkWriteResult{} <- BulkWrite.write(:mongo, issue_bulk, trans),
           %Mongo.BulkWriteResult{} <- BulkWrite.write(:mongo, card_bulk, trans) do
       :ok
      end
    end)

  end

  ##
  # updates the issue and card bulk by inserting an insert statement for issue and card.
  #
  defp make_insert_card_operation({issue_bulk, card_bulk}, board, user, list, title, pos, time) do

    issue = @new_card
            |> Issue.new(user, board)
            |> Issue.add_message_keys(title: title, list: list.title)
            |> to_map()

    card = board |> Card.new(list, title, pos, time) |> to_map()

    {UnorderedBulk.insert_one(issue_bulk, issue), UnorderedBulk.insert_one(card_bulk, card)}
  end

  @doc """
  Move a card before a card within the cards list and preserve the order of the cards.
  * `cards` the list of cards
  * `card_id` the id of the card to be moved to before the card with the id `before_id`
  * `before_id` the id of the card where the other card should moved in front of it

    (board, current_user, card, from_list, to_list, before_card)

  As the result the new board is returned.
  """
  def move_card_before(board, user, card, %BoardList{_id: from_id}, %BoardList{_id: id, cards: cards} = to_list, before_card) do

    with pos <- calc_new_pos_before(cards, before_card._id) do

      issue = case from_id == id do
        true -> ## card was moved within the same list
          @move_card
          |> Issue.new(user, board)
          |> Issue.add_message_keys(a: card.title, b: before_card.title)
          |> to_map()

        false ->
            @move_card ## card was moved between two lists
            |> Issue.new(user, board)
            |> Issue.add_message_keys(a: card.title, b: before_card.title, list: to_list.title)
            |> to_map()
      end

      with_transaction(board, fn trans ->
         with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
              {:ok, _} <- Mongo.update_one(:mongo, @cards_collection, %{_id: card._id}, %{"$set" => %{"pos" => pos, "list" => id}}) do
           :ok
         end
      end)
    end
  end

  defp calc_new_pos_before([], _id) do
    @pos_start
  end
  defp calc_new_pos_before([item], id) do
    case item._id == id do
      true  -> item.pos / 2
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

  defp calc_pos(%BoardList{cards: cards}) do
    case List.last(cards) do
      %Card{pos: pos} -> pos + @pos_gap
      nil             -> @pos_start
    end
  end

  defp calc_pos(%Board{lists: lists}) do
    case List.last(lists) do
      %BoardList{pos: pos} -> pos + @pos_gap
      nil                  -> @pos_start
    end
  end

  @doc """
  Move a card after to the end of all cards and preserve the order of the cards. It create a `MoveCard` issue.
  If cards is empty, then the position is `@pos_start` otherwise the position is `last.pos + @pos_gap`

  * `user` current user
  * `board` current board
  * `list` the list of the board
  * `card` the card to be moved to the end of the list

  It returns the new board.

  """
  def move_card_to_end(board, user, card, %BoardList{_id: from_id}, %BoardList{_id: id} = to_list) do

    pos = calc_pos(to_list)

    issue = case from_id == id do

      true -> @move_card
              |> Issue.new(user, board)
              |> Issue.add_message_keys(a: card.title)
              |> to_map()

      false -> @move_card
              |> Issue.new(user, board)
              |> Issue.add_message_keys(a: card.title, list: to_list.title)
              |> to_map()
    end

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @cards_collection, %{_id: card._id}, %{"$set" => %{"pos" => pos, "list" => id}}) do
       :ok
      end
    end)
  end


  @doc """
  Get the list from the board. The usual case is that the board was
  modified and a new version was fetched from the database. Now we
  need the updated version of the list.
  """
  def find_list(board, %BoardList{_id: list_id}) do
    find_list(board, list_id)
  end
  def find_list(board, list_id) when is_binary(list_id) do
    find_list(board, BSON.ObjectId.decode!(list_id))
  end
  def find_list(%Board{lists: lists}, list_id) do
    Enum.find(lists, fn %BoardList{_id: id} -> id == list_id end)
  end

  @doc """
  Execute the funcation by using the transaction api of the MongoDB. In case
  of an error the changes are roll backed.
  """
  def with_transaction(board, fun)
  def with_transaction(board, fun) do
    with {:ok, :ok} <- Session.with_transaction(:mongo, fn trans ->
      with :ok <- fun.(trans), do: {:ok, :ok}
    end), do: fetch(board)
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
    with {:ok, id} <-  BSON.ObjectId.decode(id) do
      :mongo
      |> Mongo.find_one(@collection, %{_id: id})
      |> to_struct()
    else
      _error -> nil
    end
  end

  @doc """
  Convert a map structure to a `Board` struct. The function fills the each list with
  the connected cards. The lists and cards are sorted according the position attribute.
  """
  def to_struct(nil) do
    nil
  end
  def to_struct(board) do

    lists = (board["lists"] || [])  |> Enum.map(fn list-> BoardList.to_struct(list) end) |> Enum.sort({:asc, BoardList})

    options = board["options"]
    %Board{
      _id: board["_id"],
      id: BSON.ObjectId.encode!(board["_id"]),
      description: board["description"],
      created: board["created"],
      modified: board["modified"],
      title: board["title"],
      members: board["members"],
      lists: lists,
      options: [color: options["color"]] |> filter_nils()
    }
  end
end
