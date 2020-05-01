defmodule Vega.SelectedCard do
  @moduledoc """


  """

  use VegaWeb, :component

  alias Vega.Board
  alias Vega.BoardList

  def mount(socket) do
    {:ok, assign(socket, action: nil, comment: nil)}
  end

  def handle_event("validate", %{"comment" => %{"comment" => comment}}, socket) do
    {:noreply, assign(socket, comment: comment)}
  end
  def handle_event("save", %{"comment" => %{"comment" => ""}}, socket) do
    {:noreply, socket}
  end
  def handle_event("save", %{"comment" => %{"comment" => comment}}, %Socket{assigns: %{current_user: user, board: board, list: list, card: card}} = socket) do
    board = Board.add_comment_to_card(board, list, card, comment, user)
    list = Board.find_list(board, list)
    card = BoardList.find_card(list, card._id)
    send(self(), {:updated_board, board})
    {:noreply, assign(socket, comment: nil, board: board, list: list, card: card)}
  end

  def render(assigns) do
    Phoenix.View.render(VegaWeb.CardView, "card.html", assigns)
  end

end