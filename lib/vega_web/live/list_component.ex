defmodule Vega.ListComponent do
  @moduledoc false

  use Phoenix.LiveComponent

  alias Vega.Board
  alias Phoenix.LiveView.Socket

  def mount(socket) do
    {:ok, assign(socket, add_card: false)}
  end

  def handle_event("add-card", _params, socket) do
    send(self(), :close_all)
    {:noreply, assign(socket, add_card: true)}
  end

  def handle_event("save", %{"card" => %{"title" => title},  "action" => action} = params, %Socket{assigns: %{current_user: user, board: board, list: list}} = socket) do

    titles = title
             |> String.split("\n")
             |> Enum.map(fn str -> String.trim(str) end)
             |> Enum.filter(fn str -> String.length(str) > 0 end)

    case titles do
      [] -> {:noreply, assign(socket, add_card: false)}
      new_titles ->
        board = Board.add_cards(board, user, list, new_titles)
        list  = Board.find_list(board, list)
        send(self(), {:updated_board, board})

        case action do
          "continue" -> {:noreply, assign(socket, board: board, list: list)}
          _          -> {:noreply, assign(socket, add_card: false, board: board, list: list)}
        end
    end
  end
  def handle_event("cancel-add-card", _params, socket) do
    {:noreply, assign(socket, add_card: false)}
  end

  def render(assigns) do
    Phoenix.View.render(VegaWeb.BoardView, "list.html", assigns)
  end

end
