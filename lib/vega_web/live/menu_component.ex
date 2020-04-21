defmodule Vega.MenuComponent do
  @moduledoc """
  This components renders the menu for a board. It is responsible for changing some attributes of the board:

  * color: set background color of the board
  * decriptions: set the optional description of the board
  """

  use VegaWeb, :component

  import VegaWeb.Views.Helpers

  def mount(socket) do
    {:ok, assign(socket, action:  nil)}
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)
    board  = fetch_board(socket)
    {:ok, assign(socket, color: get_color(board), color_changed: false)}
  end

  def handle_event("cancel", _params, socket) do
    send_me(:preview_off) ## switch off preview mode
    {:noreply, assign(socket, action: nil)}
  end

  ##
  # Close a board
  #
  def handle_event("close", _params, %Socket{assigns: %{current_user: user, board: board}} = socket) do
    case Board.is_open?(board) do
      true ->
        board = Board.close(board, user)
        send(self(), {:updated_board, board})
        {:noreply, assign(socket, board: board)}
      false ->
        {:noreply, socket}
    end
  end

  ##
  # Open a closed board
  #
  def handle_event("open", _params, %Socket{assigns: %{current_user: user, board: board}} = socket) do
    case Board.is_closed?(board) do
      true ->
        board = Board.open(board, user)
        send(self(), {:updated_board, board})
        {:noreply, assign(socket, board: board)}
      false ->
        {:noreply, socket}
    end
  end

  ##
  # Delete a closed board
  #
  def handle_event("delete", _params, %Socket{assigns: %{board: board}} = socket) do
    case Board.is_closed?(board) do
      true ->
        Board.delete(board)
        send(self(), :deleted)
      false ->
        []
    end
    {:noreply, socket}
  end

  ##
  # Copy a board
  #
  def handle_event("copy", _params, %Socket{assigns: %{board: board}} = socket) do
    value = gettext("Copy of %{title}", title: board.title)
    {:noreply, assign(socket, action: :copy, value: value)}
  end
  ##
  # Update/validate the change of selection in case of 'copy board'
  #
  def handle_event("validate", %{"copy" => %{"title" => new_title}}, socket) do
    {:noreply, assign(socket, value: new_title)}
  end
  def handle_event("save", %{"copy" => %{"title" => new_title}},
        %Socket{assigns: %{current_user: user, board: board}} = socket) do

    case VegaWeb.BoardView.validate_title(new_title) do
      true ->
        board = Board.clone(board, user, new_title)
        send_me({:load, board.id})
        {:noreply, assign(socket, action: nil)}
      false ->
        {:noreply, socket}
    end
  end

  def handle_event("select", %{"color" => color}, %Socket{assigns: %{board: board}} = socket) do
    {:noreply, assign(socket, color: color, color_changed: get_color(board) != color)}
  end
  def handle_event("save-color", _params, %Socket{assigns: %{current_user: user, board: board, color: color, color_changed: color_changed}} = socket) do
    case color_changed do
      true ->
        board = Board.set_color(board, user, color)
        send(self(), {:updated_board, board})
      false -> []
      end
    {:noreply, socket}
  end

  def render(assigns) do
    Phoenix.View.render(VegaWeb.BoardView, "menu.html", assigns)
  end

  defp send_me(msg) do
    send(self(), msg)
  end

end
