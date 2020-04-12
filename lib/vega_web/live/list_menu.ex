defmodule Vega.ListMenu do
  @moduledoc """

  This module represents the pop-over menu for the selected list. It is responsible to modify attributes of the list:

  * move a list
  * copy a list

  """

  use Phoenix.LiveComponent

  import VegaWeb.Gettext

  alias Vega.Board
  alias Phoenix.LiveView.Socket
  alias Vega.BoardOverview
  alias Vega.BoardList
  alias Vega.WarningColorRule

  def mount(socket) do
    {:ok, assign(socket, action: nil)}
  end

  @doc"""
  Event-Handling:

  * `cancel` : closing the current form and shows the options again
  * `move`  : move the list
  * `validate` : validate the current form (moving, edit title, etc)
  * `save` : save the current form (moving, edit title, etc)
  """
  def handle_event("cancel", _params, socket) do
    send_me(:preview_off) ## switch off preview mode
    {:noreply, assign(socket, action: nil)}
  end
  ##
  # Sort cards
  ##
  def handle_event("sort-cards", _params, socket) do
    {:noreply, assign(socket, action: :sort_cards, value: "none", order: "asc")}
  end
  def handle_event("sort-by-card-name", _params, %Socket{assigns: %{board: board, order: order, list: list}} = socket) do
    value = "sort-by-card-name"
    list  = update_board(board, list, order, value)
    {:noreply, assign(socket, list: list, value: value)}
  end
  def handle_event("sort-by-modification", _params, %Socket{assigns: %{board: board, order: order, list: list}} = socket) do
    value = "sort-by-modification"
    list  = update_board(board, list, order, value)
    {:noreply, assign(socket, list: list, value: value)}
  end
  def handle_event("sort-by-creation", _params, %Socket{assigns: %{board: board, order: order, list: list}} = socket) do
    value = "sort-by-creation"
    list  = update_board(board, list, order, value)
    {:noreply, assign(socket, list: list, value: value)}
  end
  ##
  # We are updating the list in the preview mode, so the user can see the sorting in action
  ##
  def handle_event("validate", %{"sort_cards" => %{"order" => order}}, %Socket{assigns: %{value: "none"}} = socket) do
    {:noreply, assign(socket, order: order)}
  end
  def handle_event("validate", %{"sort_cards" => %{"order" => order}}, %Socket{assigns: %{board: board, value: value, list: list}} = socket) do
    list = update_board(board, list, order, value)
    {:noreply, assign(socket, order: order, list: list)}
  end
  def handle_event("save", %{"sort_cards" => _params}, %Socket{assigns: %{board: board, list: list, current_user: user}} = socket) do
    board = Vega.Board.sort_cards(board, list, list.cards, user)
    send_me({:close_menu_list, board}) ## update board, switch off preview mode
    {:noreply, assign(socket, action: nil)}
  end
  ##
  # Move cards
  ##
  def handle_event("move-cards", _params, %Socket{assigns: %{list: list}} = socket) do
    {:noreply, assign(socket, action: :move_cards, value: list.id)}
  end
  def handle_event("select-list", %{"id" => list_id},  %Socket{assigns: %{board: board}} = socket) do
    with list when list != nil <- Board.find_list(board, list_id) do
      {:noreply, assign(socket, value: list.id)}
    else
      _ -> {:noreply, assign(socket, action: nil)}
    end
  end
  def handle_event("save", %{"move_cards" => %{"move_cards" => "true"}},
        %Socket{assigns: %{current_user: user, board: board, list: list, value: to_id}} = socket) do
    with to when to != nil <- Board.find_list(board, to_id) do
      board = Board.move_cards_of_list(board, list, to, user)
      send_me({:close_menu_list, board})
    end
    {:noreply, assign(socket, action: nil)}
  end
  #  def move_cards_of_list(board, %BoardList{cards: cards} = from, %BoardList{_id: to_id} = to, user) do
  def handle_event("color", _params, %Socket{assigns: %{list: list}} = socket) do
    case list.color do
      nil  -> {:noreply, assign(socket, action: :color, n_value: 0, color_value: "none", warning_value: "none")}
      rule -> {:noreply, assign(socket, action: :color, n_value: rule.n, color_value: rule.color, warning_value: rule.warning)}
    end
  end
  def handle_event("validate", %{"color" => %{"n" => new_n}}, %Socket{assigns: %{n_value: old}} = socket) do
    n = parse_integer(new_n, old)
    {:noreply, assign(socket, n_value: n)}
  end
  def handle_event("select-color", %{"color" => color}, socket) do
    {:noreply, assign(socket, color_value: color)}
  end
  def handle_event("select-warning", %{"color" => color}, socket) do
    {:noreply, assign(socket, warning_value: color)}
  end
  def handle_event("save", %{"color" => %{"n" => new_n}},
                   %Socket{assigns: %{current_user: user, board: board, list: list, n_value: old,
                           color_value: color, warning_value: warning}} = socket) do

    n     = parse_integer(new_n, old)
    rule  = WarningColorRule.new(color, n, warning)
    board = Board.set_list_color(board, list, user, rule)
    send_me({:close_menu_list, board})

    {:noreply, assign(socket, action: nil)}
  end

  def handle_event("change-name", _params, %Socket{assigns: %{list: list}} = socket) do
    {:noreply, assign(socket, action: :change_name, value: list.title)}
  end
  ##
  # Copy a list
  #
  def handle_event("copy", _params, %Socket{assigns: %{list: list}} = socket) do
    {:noreply, assign(socket, action: :copy, value: list.title)} ## todo gettext("Copy of #{title}", [title: list.title])
  end
  ##
  # Update/validate the change of selection in case of 'copy list'
  #
  def handle_event("validate", %{"copy" => %{"title" => new_title}}, socket) do
    {:noreply, assign(socket, value: new_title)}
  end
  def handle_event("save", %{"copy" => %{"title" => new_title}},
        %Socket{assigns: %{current_user: user, board: board, list: list}} = socket) do

    case VegaWeb.BoardView.validate_title(new_title) do
      true ->
        board = Board.copy_list(board, user, list, new_title)
        send_me({:close_menu_list, board})
        {:noreply, assign(socket, action: nil)}
      false ->
        {:noreply, socket}
    end
  end

  ##
  # Move a list
  #
  def handle_event("move", _params, %Socket{assigns: %{current_user: user, board: board, list: list}} = socket) do
    new_board_id = board.id
    boards       = BoardOverview.fetch_personal_boards(user, %{title: 1, lists: 1}) |> Enum.map(&to_struct(&1))
    board        = Enum.find(boards, fn board -> board.id == new_board_id end)
    socket       = socket
                   |> assign_boards(boards, board)
                   |> assign_positions(board, list)

    {:noreply, assign(socket, action: :move, boards: boards)}
  end
  ##
  # Update/validate the change of selection
  #
  def handle_event("validate", %{"move" => %{"new_board" => new_board, "new_position" => new_position}},
                   %Socket{assigns: %{boards: boards, list: list}} = socket) do
    new_board = Enum.find(boards, fn board -> board.id == new_board end)
    socket = socket
             |> assign_boards(boards, new_board)
             |> assign_positions(new_board, list)

    {:noreply, assign(socket, new_board: new_board.id, new_position: new_position)}
  end
  def handle_event("save", %{"move" => %{"new_board" => to_id, "new_position" => new_position}},
                   %Socket{assigns: %{current_user: user, board: from, list: list}} = socket) do

    with to when to != nil <- Board.fetch(to_id, user) do
      before_list = list_in_pos(to.lists, new_position)
      board       = move_list(user, from, list, to, before_list)
      send_me({:close_menu_list, board})
    else
      _error ->
        send_me({:close_menu_list, from})
    end

    {:noreply, assign(socket, action: nil)}
  end

  def handle_event("validate", %{"name" => %{"title" => new_title}}, socket) do
    {:noreply, assign(socket, value: new_title)}
  end

  def handle_event("save", %{"name" => %{"title" => new_title}}, %Socket{assigns: %{action: :change_name, current_user: user, board: board, list: list}} = socket) do
    title = String.trim(new_title)
    case VegaWeb.BoardView.validate_title(title) do
      true ->
        board = Board.set_list_title(board, list, user, title)
        send_me({:updated_board, board})
        {:noreply, assign(socket, action: nil, board: board, list: Board.find_list(board, list))}
      false ->
          {:noreply, assign(socket, value: new_title)}
    end
  end
  def render(assigns) do
    Phoenix.View.render(VegaWeb.BoardView, "list-menu.html", assigns)
  end

  defp assign_boards(socket, boards, current_board) do
    board_options = boards
      |> Enum.map(fn b ->
      title = case current_board.id == b.id do
        true  -> b["title"] <> gettext(" (current)")
        false -> b["title"]
      end
      [key: title, value: b.id]
    end)

    assign(socket, board_options: board_options, new_board: current_board.id)
  end

  defp assign_positions(socket, board, current_list) do

    pos       = Enum.find_index(board.lists, fn l -> l.id == current_list.id end) || 0
    positions = board.lists
                |> Enum.with_index(1)
                |> Enum.map(fn {l,i} -> case l.id == current_list.id do
                      true  -> [key: to_string(i) <> gettext(" (current)"), value: to_string(i)]
                      false -> [key: to_string(i), value: to_string(i)]
                    end
                   end)
                |> align_posistions()

    assign(socket, position_options: positions, new_position: to_string(pos + 1))
  end

  defp align_posistions([]) do
    [[key: "1", value: "1"]]
  end
  defp align_posistions(xs) do
    xs
  end

  defp to_struct(%{"lists" => lists} = board) do

    lists = lists
            |> Enum.map(fn list ->
                  list
                  |> Map.put(:id, BSON.ObjectId.encode!(list["_id"]))
                  |> Map.put(:pos, list["pos"])
                end)
            |> Enum.sort({:asc, BoardList})

    Map.put(board, :lists, lists)
  end
  defp to_struct(board) do
    Map.put(board, :lists, [])
  end

  ##
  # returns the list for the given position
  #
  defp list_in_pos([], _pos) do
    nil
  end
  defp list_in_pos(lists, pos) do

    n          = length(lists)
    {pos, _}   = Integer.parse(pos)
    case pos do
      i when i >= n -> nil
      i when i >= 0 -> Enum.at(lists, i)
      _             -> List.first(lists)
    end
  end

  ##
  # parse an integer and returns the value or in case of wrong input the old value
  #
  defp parse_integer("", old) do
    old
  end
  defp parse_integer(str, old) do
    case Integer.parse(str) do
      {n, _} -> n
      _      -> old
    end
  end

  ##
  # Try to move list:
  # if before_list == list => do nothing
  # if board is the same => remove `to`
  #
  defp move_list(user, from, list, to, nil) do
    case from.id == to.id do
      true  -> Board.move_list(user, list, to, nil)
      false -> Board.move_list(user, from, list, to)
    end
  end
  defp move_list(user, from, list, to, before_list) do
    case list.id == before_list.id do
      true  -> from
      false ->
        case from.id == to.id do
          true  ->
            Board.move_list(user, list, to, before_list)
          false -> Board.move_list(user, from, list, to, before_list)
        end
    end
  end

  defp send_me(msg) do
    send(self(), msg)
  end

  defp update_board(board, list, order, value) do
    ## we validate the order value
    ## todo: maybe put this into a function
    order = case order do
      "asc"  -> order
      "desc" -> order
      _      -> "asc"
    end
    cards = sort_cards(list, order, value)    ## sort the cards
    list  = %BoardList{list | cards: cards}   ## update the list
    lists = Enum.map(board.lists, fn          ## update the lists
      that -> case that.id == list.id do
                true -> list
                false -> that
              end end)
    send_me({:preview, %Board{board | lists: lists}}) ## update the board and switch on the preview mode
    list
  end

  defp sort_cards(list, _order, "none")  do
    list
  end
  defp sort_cards(list, order, value) do
    case {value, order} do
      {"sort-by-card-name", "asc"}    -> Enum.sort(list.cards, fn left, right -> compare_asc(left.title, right.title) end)
      {"sort-by-card-name", "desc"}   -> Enum.sort(list.cards, fn left, right -> compare_desc(left.title, right.title) end)
      {"sort-by-creation", "asc"}     -> Enum.sort(list.cards, fn left, right -> left.created <= right.created end)
      {"sort-by-creation", "desc"}    -> Enum.sort(list.cards, fn left, right -> left.created >= right.created end)
      {"sort-by-modification", "asc"} -> Enum.sort(list.cards, fn left, right -> left.modified <= right.modified end)
      _other                          -> Enum.sort(list.cards, fn left, right -> left.modified >= right.modified end)
    end
  end

  defp compare_asc(left, right) do
    result = Cldr.Collation.Insensitive.compare(left, right)
    result == :eq || result == :lt
  end
  defp compare_desc(left, right) do
    result = Cldr.Collation.Insensitive.compare(left, right)
    result == :eq || result == :gt
  end

end