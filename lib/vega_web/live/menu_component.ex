defmodule Vega.MenuComponent do
  @moduledoc """
  This components renders the menu for a board. It is responsible for changing some attributes of the board:

  * color: set background color of the board
  * decriptions: set the optional description of the board
  """

  use VegaWeb, :component

  import VegaWeb.Views.Helpers

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)
    board  = fetch_board(socket)
    {:ok, assign(socket, color: get_color(board), color_changed: false)}
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

end
