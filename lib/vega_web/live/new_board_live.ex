defmodule VegaWeb.NewBoardLive do
  @moduledoc """

  Live view form to create a new board

  """

  use VegaWeb, :live

  alias Vega.User
  alias Vega.Board

  def mount(_params, session, socket) do

    socket = session
             |> set_locale()
             |> fetch_user(socket)
             |> assign_asserts("new-board")

    {:ok, assign(socket, title: nil, color: nil)}
  end

  def handle_event("validate", %{"new_board" => %{"title" => title}}, socket) do
    {:noreply, assign(socket, title: title)}
  end
  def handle_event("select", %{"color" => color}, socket) do
    {:noreply, assign(socket, color: color)}
  end
  def handle_event("save", %{"new_board" => %{"title" => title}}, socket) do
    case VegaWeb.BoardView.has_title(title) do
      true ->
        board = socket |> fetch_user() |> Board.new(title, color: socket.assigns.color)
        {:noreply, redirect(socket, to: Routes.live_path(VegaWeb.Endpoint, VegaWeb.BoardLive, board.id))}
      false ->
        {:noreply, assign(socket, title: title)}
    end
  end

  @doc """
  Render the new board live
  """
  def render(assigns) do
    Phoenix.View.render(VegaWeb.BoardView, "new.html", assigns)
  end

end
