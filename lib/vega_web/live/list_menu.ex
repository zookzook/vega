defmodule Vega.ListMenu do
  @moduledoc false

  use Phoenix.LiveComponent

  alias Vega.Board
  alias Phoenix.LiveView.Socket

  def mount(socket) do
    {:ok, assign(socket, action: nil)}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, action: nil)}
  end
  def handle_event("change-name", params, %Socket{assigns: %{list: list}} = socket) do
    {:noreply, assign(socket, action: :change_name, value: list.title)}
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

end