defmodule Vega.ListMenu do
  @moduledoc """

  This module represents the pop-over menu for the selected list. It is responsible to modify attributes of the list

  """

  use Phoenix.LiveComponent

  alias Vega.Board
  alias Phoenix.LiveView.Socket
  alias Vega.BoardOverview
  alias Vega.BoardList

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
    {:noreply, assign(socket, action: nil)}
  end
  def handle_event("change-name", _params, %Socket{assigns: %{list: list}} = socket) do
    {:noreply, assign(socket, action: :change_name, value: list.title)}
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
      send(self(), {:close_menu_list, board})
    else
      _error ->
        send(self(), {:close_menu_list, from})
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
        send(self(), {:updated_board, board})
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
        true  -> b["title"] <> " (current)"
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
                      true  -> [key: "#{i} (current)", value: to_string(i)]
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

end