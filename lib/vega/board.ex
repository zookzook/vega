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
  alias Vega.Issue
  alias Vega.WarningColorRule

  @copy_list          IssueConsts.encode(:copy_list)
  @new_board          IssueConsts.encode(:new_board)
  @new_card           IssueConsts.encode(:new_card)
  @set_description    IssueConsts.encode(:set_description)
  @add_comment        IssueConsts.encode(:add_comment)
  @set_title          IssueConsts.encode(:set_title)
  @set_board_color    IssueConsts.encode(:set_board_color)
  @add_list           IssueConsts.encode(:add_list)
  @delete_list        IssueConsts.encode(:delete_list)
  @sort_cards         IssueConsts.encode(:sort_cards)
  @move_card          IssueConsts.encode(:move_card)
  @move_list          IssueConsts.encode(:move_list)
  @set_list_color     IssueConsts.encode(:set_list_color)
  @move_cards_of_list IssueConsts.encode(:move_cards_of_list)
  @archive_card       IssueConsts.encode(:archive_card)
  @archive_list       IssueConsts.encode(:archive_list)
  @unarchive_card     IssueConsts.encode(:unarchive_card)
  @unarchive_list     IssueConsts.encode(:unarchive_list)
  @clone_board        IssueConsts.encode(:clone_board)
  @open_board         IssueConsts.encode(:open_board)
  @close_board        IssueConsts.encode(:close_board)

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

  @derived_attributes [:id]

  defstruct [
    :_id,         ## the ObjectId of the board
    :options,     ## options for styling etc.
    :id,          ## the ObjectId as string
    :created,     ## the creation date
    :modified,    ## the last modification date
    :title,       ## the title
    :description, ## optional: the description
    :members,     ## the list of members of the board
    :lists,       ## the lists of the board
    :closed       ## closing date
  ]

  @doc """
  Create a new empty board with the `title`.

  ## Example
      iex> Vega.Board.new(user, "My first Board")

  """
  def new(%User{_id: id} = user, title, opts \\ %{}) do
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
            |> Issue.dump()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.insert_one(:mongo, @collection, dump(board), trans)  do
        :ok
      end
    end)
  end

  @doc"""
  Perform a deep copy.
  """
  def clone(board, user, title) do
    new_board = %Board{
      _id: Mongo.object_id(),
      title: title,
      created: DateTime.utc_now(),
      modified: DateTime.utc_now(),
      members: board.members,
      options: board.options
    }

    deep_copy = Enum.map(board.lists, fn list -> BoardList.clone(new_board, list) end)
    new_lists = Enum.map(deep_copy, fn {_id, list, _cards} -> list end)
    bulk      = deep_copy
                |> Enum.map(fn {_id, _list, cards} -> cards end)
                |> Enum.reduce(UnorderedBulk.new(@cards_collection), fn bulk, acc -> add(acc, bulk) end)

    new_board = %Board{new_board | lists: new_lists}

    list_mapping = deep_copy
                   |> Enum.map(fn {old_id, list, _card} -> {old_id, list._id} end)
                   |> Enum.into(%{})

    issues = board
             |> Issue.fetch_all_raw()
             |> Issue.clone_issues(new_board._id, list_mapping)

    issues_bulk = UnorderedBulk.new(@issues_collection)
    issues_bulk = Enum.reduce(issues, issues_bulk, fn issue, bulk -> UnorderedBulk.insert_one(bulk, issue) end)

    issue = @clone_board
            |> Issue.new(user, new_board)
            |> Issue.add_message_keys(title: board.title, board: new_board.title)
            |> Issue.dump()

    with_transaction(new_board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.insert_one(:mongo, @collection, dump(new_board), trans),
           %Mongo.BulkWriteResult{} <- BulkWrite.write(:mongo, bulk, trans),
           %Mongo.BulkWriteResult{} <- BulkWrite.write(:mongo, issues_bulk, trans) do
        :ok
      end
    end)
  end

  def add(%UnorderedBulk{coll: coll_a} = a,  %UnorderedBulk{coll: coll_b} = b) when coll_a == coll_b do
    %UnorderedBulk{coll: coll_a,
      inserts: a.inserts ++ b.inserts,
      updates: a.updates ++ b.updates,
      deletes: a.deletes ++ b.deletes}
  end

  @doc """
  Delete a board with all isses and cards attached to that board.
  ## Example

    iex> {:ok, issue, cards} = Vega.Board.delete(board)

  """
  def delete(%Board{_id: id}) do

    ## todo: cleanup the archived-collections as well
    with {:ok, {n_issues, n_cards}} <- Session.with_transaction(:mongo, fn trans ->
      with {:ok, %Mongo.DeleteResult{deleted_count: n_issues}} <- Mongo.delete_many(:mongo, @issues_collection, %{board: id}, trans),
           {:ok, %Mongo.DeleteResult{deleted_count: n_cards}} <- Mongo.delete_many(:mongo, @cards_collection, %{board: id}, trans),
           {:ok, _} <- Mongo.delete_one(:mongo, @collection, %{_id: id}, trans) do
        {:ok, {n_issues, n_cards}}
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
            |> Issue.dump()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$set" => %{"title" => title}}, trans) do
        :ok
      end
    end)
  end

  @doc """
  Set the color of the board and returns the new board.

  ## Example

    iex> Vega.Board.set_color(board, user, red")

  """
  def set_color(%Board{_id: id} = board, user, color) do

    issue = @set_board_color
            |> Issue.new(user, board)
            |> Issue.add_message_keys(color: color, board: board.title)
            |> Issue.dump()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$set" => %{"options.color" => color}}, trans) do
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
            |> Issue.dump()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$set" => %{"description" => description}}, trans) do
        :ok
      end
    end)

  end

  @doc """
  Set the title of the list and returns the new board.

  ## Example

    iex> Vega.Board.set_list_title(board, list, user, "New title")

  """
  def set_list_title(%Board{_id: id} = board, %BoardList{_id: list_id} = list, user, title) do

    issue = @set_title
            |> Issue.new(user, board, list)
            |> Issue.add_message_keys(title: title, list: list.title)
            |> Issue.dump()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id, "lists._id": list_id}, %{"$set" => %{"lists.$.title" => title}}) do
        :ok
      end
    end)
  end

  @doc """
  Set the color rule of the list. If color is nil, then the color rule is removed.

  ## Example

    iex> color = WarningColorRule.new("green", 3, "red")
    iex> Vega.Board.set_list_color(board, list, user, color)

  """
  def set_list_color(%Board{_id: id} = board, %BoardList{_id: list_id} = list, user, color) do
    issue = @set_list_color
            |> Issue.new(user, board, list)
            |> Issue.add_message_keys(list: list.title, color: color != nil)
            |> Issue.dump()

    modifier = case color do
      nil    -> %{"$unset" => %{"lists.$.color" => 1}}
      _other -> %{"$set" => %{"lists.$.color" => color |> WarningColorRule.dump()}}
    end

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id, "lists._id": list_id}, modifier) do
        :ok
      end
    end)
  end

  @doc """
  Add a new list to the board. It creates an issue `Vega.Issue.AddList` for the history and returns the new board.

  ## Example

    iex> Vega.Board.add_list(board, user, "To do")

  """
  def add_list(%Board{_id: id, title: board_title, lists: lists} = board, user, title) do

    issue = @add_list
            |> Issue.new(user, board)
            |> Issue.add_message_keys(title: title, board: board_title)
            |> Issue.dump()

    pos     = calc_pos(lists)
    column  = title |> BoardList.new(pos) |> BoardList.dump()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$push" => %{"lists" => column}}, trans) do
        :ok
      end
    end)
  end

  @doc"""
  Copy a list of the board and duplicates all cards.

  ## Example

    iex> Vega.Board.copy_list(board, user, list, "new title")
  """
  def copy_list(%Board{_id: id, lists: lists} = board, user, %BoardList{title: title, cards: cards, color: color}, new_title) do

    issue = @copy_list
            |> Issue.new(user, board)
            |> Issue.add_message_keys(list: title, board: board.title, title: title)
            |> Issue.dump()

    pos      = calc_pos(lists)
    new_list = new_title |> BoardList.new(pos) |> Map.put(:color, color)
    list_id  = new_list._id

    bulk = UnorderedBulk.new(@cards_collection)
    bulk = Enum.reduce(cards, bulk, fn card, bulk -> UnorderedBulk.insert_one(bulk, %Card{card | _id: Mongo.object_id(), list: list_id} |> Card.dump()) end)

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           %Mongo.BulkWriteResult{} <- BulkWrite.write(:mongo, bulk, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$push" => %{"lists" => new_list |> BoardList.dump()}}, trans) do
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
            |> Issue.dump()

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
  def move_list(user, %BoardList{} = list, %Board{_id: id, lists: lists} = to, before_list) do

    pos   = calc_pos(lists, before_list)

    msg = case before_list do
            nil    -> [a: list.title]
            _other -> [a: list.title, b: before_list.title]
    end
    issue = @move_list
            |> Issue.new(user, to)
            |> Issue.add_message_keys(msg)
            |> Issue.dump()

    with_transaction(to, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id, "lists._id": list._id}, %{"$set" => %{"lists.$.pos" => pos}}) do
        :ok
      end
    end)

  end

  @doc """
  Move a list after to the end of all lists of another board and preserve the order of the cards.
  If 'lists' of the board is empty, then the position is `@pos_start` otherwise the position is `last.pos + @pos_gap`

  * `from` move the list from the board
  * `user` current user
  * `list` the list to be moved to the end of the lists
  * `to` move the list to the board

  It returns the `from` board.

  """
  #def xmove_list_before(%Board{} = from, user, list, before_list, %Board{} = to) do
  #
  #end
  def move_list(user, %Board{_id: from_id} = from, list, %Board{_id: to_id, lists: lists} = to, list_before \\ nil) do

    pos = calc_pos(lists, list_before)

    issue_from = @move_list
            |> Issue.new(user, from)
            |> Issue.add_message_keys(a: list.title, to: to.title)
            |> Issue.dump()

    issue_to = @move_list
            |> Issue.new(user, to)
            |> Issue.add_message_keys(a: list.title, from: from.title)
            |> Issue.dump()

    list = BoardList.dump(%BoardList{list | pos: pos})

    with_transaction(from, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue_from, trans),
           {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue_to, trans),
           {:ok, _} <- Mongo.update_many(:mongo, @cards_collection, %{list: list._id, board: from_id}, %{"$set" => %{"board" => to_id}}, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: from_id}, %{"$pull" => %{"lists" => %{"_id" => list._id}}}, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: to_id}, %{"$push" => %{"lists" => list}}, trans)  do
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
    iex> board = Vega.Board.sort_cards(board, a, cards, user)

  """
  def sort_cards(board, list, cards, user) do

    issue = @sort_cards
            |> Issue.new(user, board)
            |> Issue.add_message_keys(list: list.title)
            |> Issue.dump()

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

  @doc """
  Add the new comment to the card
  """
  def add_comment_to_card(board, card, comment, user) do

    issue = @add_comment
            |> Issue.new(user, board)
            |> Issue.add_message_keys(comment: comment)
            |> Issue.dump()

    comment = %{_id: Mongo.object_id(), text: comment, user: user._id, created: DateTime.utc_now()}

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @cards_collection, %{_id: card._id}, %{"$push": %{comments: comment}}, trans) do
        :ok
      end
    end)
  end

  @doc """
  Find the card of the list in the board. Returns a tuple `{list, card}`
  """
  def find_card(board, list_id, card_id) do
    with list when list != nil <- find_list(board, list_id),
         card when card != nil <- BoardList.find_card(list, card_id) do
      {list, card}
    end
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
            |> Issue.dump()

    pos = calc_pos(list)
    card = board |> Card.new(list, title, pos) |> Card.dump()

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
            |> Issue.dump()

    card = board |> Card.new(list, title, pos, time) |> Card.dump()

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

    with pos <- calc_pos(cards, before_card._id) do

      issue = case from_id == id do
        true -> ## card was moved within the same list
          @move_card
          |> Issue.new(user, board)
          |> Issue.add_message_keys(a: card.title, b: before_card.title)
          |> Issue.dump()

        false ->
            @move_card ## card was moved between two lists
            |> Issue.new(user, board)
            |> Issue.add_message_keys(a: card.title, b: before_card.title, list: to_list.title)
            |> Issue.dump()
      end

      with_transaction(board, fn trans ->
         with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
              {:ok, _} <- Mongo.update_one(:mongo, @cards_collection, %{_id: card._id}, %{"$set" => %{"pos" => pos, "list" => id}}) do
           :ok
         end
      end)
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
              |> Issue.dump()

      false -> @move_card
              |> Issue.new(user, board)
              |> Issue.add_message_keys(a: card.title, list: to_list.title)
              |> Issue.dump()
    end

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @cards_collection, %{_id: card._id}, %{"$set" => %{"pos" => pos, "list" => id}}) do
       :ok
      end
    end)
  end

  @doc """
  Move the cards to the end of another list
  """
  def move_cards_of_list(board, %BoardList{cards: cards} = from, %BoardList{_id: to_id} = to, user) do

    pos   = calc_pos(to)

    issue = @move_cards_of_list
            |> Issue.new(user, board, from)
            |> Issue.add_message_keys(from: from.title, to: to.title, count: length(cards))
            |> Issue.dump()

    bulk = UnorderedBulk.new(@cards_collection)
   {bulk, _pos} = Enum.reduce(cards, {bulk, pos}, fn card, {bulk, pos} -> {UnorderedBulk.update_one(bulk, %{_id: card._id}, %{"$set" => %{"pos" => pos, "list" => to_id}}), pos + @pos_gap} end)

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           %Mongo.BulkWriteResult{} <- BulkWrite.write(:mongo, bulk, trans) do
        :ok
      end
    end)

  end

  @doc """
  Close the board. The `:closed` attribute of the board is set to the current time and after that, it is closed
  and hidden. Only closed boards can be deleted.
  """
  def close(%Board{_id: id} = board, user) do

    issue = @close_board
            |> Issue.new(user, board)
            |> Issue.add_message_keys(board: board.title)
            |> Issue.dump()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$set" => %{"closed" => DateTime.utc_now()}}) do
        :ok
      end
    end)

  end

  @doc """
  Close the board. The `:closed` attribute of the board is set to the current time and after that, it is closed
  and hidden. Only closed boards can be deleted.
  """
  def open(%Board{_id: id} = board, user) do

    issue = @open_board
            |> Issue.new(user, board)
            |> Issue.add_message_keys(board: board.title)
            |> Issue.dump()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id}, %{"$unset" => %{"closed" => 1}}) do
        :ok
      end
    end)

  end

  @doc """
  Archive the list. The `:archived` attribute of the list is set to the current time and after that, it is archived
  and hidden.
  """
  def archive_list(%Board{_id: id} = board, %BoardList{_id: list_id, cards: cards} = list, user) do

    issue = @archive_list
            |> Issue.new(user, board)
            |> Issue.add_message_keys(list: list.title, count: length(cards))
            |> Issue.dump()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id, "lists._id": list_id}, %{"$set" => %{"lists.$.archived" => DateTime.utc_now()}}) do
        :ok
      end
    end)

  end

  @doc """
  Archive the list. The `:archived` attribute of the list is set to the current time and after that, it is archived
  and hidden.
  """
  def unarchive_list(%Board{_id: id} = board, %BoardList{_id: list_id, cards: cards} = list, user) do

    issue = @unarchive_list
            |> Issue.new(user, board)
            |> Issue.add_message_keys(list: list.title, count: length(cards))
            |> Issue.dump()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @collection, %{_id: id, "lists._id": list_id}, %{"$unset" => %{"lists.$.archived" => 1}}) do
        :ok
      end
    end)

  end

  @doc """
  Archive the card. The `:archived` attribute of the card is set to the current time and after that, it is archived
  and hidden.
  """
  def archive_card(board, card, user) do

    issue = @archive_card
            |> Issue.new(user, board)
            |> Issue.add_message_keys(card: card.title)
            |> Issue.dump()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @cards_collection, %{_id: card._id}, %{"$set" => %{"archived" => DateTime.utc_now()}}) do
        :ok
      end
    end)

  end

  @doc """
  Unarchive the card. Removes the `:archived` attribute of the card so the card is visible again.
  """
  def unarchive_card(board, card, user) do

    issue = @unarchive_card
            |> Issue.new(user, board)
            |> Issue.add_message_keys(card: card.title)
            |> Issue.dump()

    with_transaction(board, fn trans ->
      with {:ok, _} <- Mongo.insert_one(:mongo, @issues_collection, issue, trans),
           {:ok, _} <- Mongo.update_one(:mongo, @cards_collection, %{_id: card._id}, %{"$unset" => %{"archived" => 1}}) do
        :ok
      end
    end)

  end

  @doc """
  Returns all archived cards of the list

  ## Example

    iex> Board.fetch_archived_cards(board, list)
  """
  def fetch_archived_cards(%Board{_id: id}, %BoardList{_id: list_id}) do
    Mongo.find(:mongo, @cards_collection, %{board: id, list: list_id, archived: %{"$exists": true}})
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
    |> load()
  end

  def fetch(%Board{_id: id}, %User{_id: user_id}) do
    :mongo
    |> Mongo.find_one(@collection, %{_id: id, "members.id": user_id})
    |> load()
  end
  def fetch(id, %User{_id: user_id}) when is_binary(id) do
    with {:ok, id} <-  BSON.ObjectId.decode(id) do
      :mongo
      |> Mongo.find_one(@collection, %{_id: id, "members.id": user_id})
      |> load()
    else
      _error -> nil
    end
  end
  def fetch(%Board{_id: id}) do
    :mongo
    |> Mongo.find_one(@collection, %{_id: id})
    |> load()
  end
  def fetch(id) when is_binary(id) do
    with {:ok, id} <-  BSON.ObjectId.decode(id) do
      :mongo
      |> Mongo.find_one(@collection, %{_id: id})
      |> load()
    else
      _error -> nil
    end
  end

  def dump(%Board{} = board) do
    board
    |> Map.drop(@derived_attributes)
    |> to_map()
  end

  @doc """
  Convert a map structure to a `Board` struct. The function fills the each list with
  the connected cards. The lists and cards are sorted according the position attribute.
  """
  def load(nil) do
    nil
  end
  def load(board) do

    lists = (board["lists"] || [])
            |> Enum.reject(fn list -> BoardList.is_archived(list) end)
            |> Enum.map(fn list-> BoardList.load(list) end)
            |> Enum.sort({:asc, BoardList})

    options = board["options"]
    %Board{
      _id: board["_id"],
      id: BSON.ObjectId.encode!(board["_id"]),
      description: board["description"],
      created: board["created"],
      modified: board["modified"],
      closed: board["closed"],
      title: board["title"],
      members: board["members"],
      lists: lists,
      options: [color: options["color"]] |> filter_nils()
    }
  end



  def is_closed?(%Board{closed: date}) do
    date != nil
  end
  def is_closed?(_other) do
    false
  end
  def is_open?(%Board{closed: date}) do
    date == nil
  end
  def is_open?(%{"closed" => date}) do
    date == nil
  end
  def is_open?(_other) do
    true
  end

  ##
  # calculates the new position before another element (optional)
  #
  defp calc_pos(xs, before \\ nil)
  defp calc_pos(%BoardList{cards: cards}, nil) do
    case List.last(cards) do
      %Card{pos: pos} -> pos + @pos_gap
      nil             -> @pos_start
    end
  end
  defp calc_pos(xs, %BoardList{_id: id}) do
    calc_pos(xs, id)
  end
  defp calc_pos(lists, nil) do
    case List.last(lists) do
      %BoardList{pos: pos} -> pos + @pos_gap
      nil                  -> @pos_start
    end
  end
  defp calc_pos([], _id) do
    @pos_start
  end
  defp calc_pos([item], id) do
    case item._id == id do
      true  -> item.pos / 2
      false -> 0.0
    end
  end
  defp calc_pos([pre, next | xs], id) do
    case pre._id == id do
      true  -> pre.pos / 2
      false ->
        case next._id == id do
          true -> pre.pos + (next.pos - pre.pos) / 2
          false -> calc_pos([next | xs], id)
        end
    end
  end
end
