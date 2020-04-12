defmodule VegaWeb.BoardLive do

  use VegaWeb, :live

  import VegaWeb.Views.Helpers

  alias Vega.Board
  alias Vega.BoardList
  alias Vega.Issue

  def mount(params, session, socket) do
    socket = session
             |> set_locale()
             |> fetch_user(socket)
             |> assign_asserts("board")

    params["id"]
    |> Board.fetch()
    |> mount_board(socket)
  end

  defp mount_board(nil, socket) do
    {:ok, redirect(socket, to: "/")}
  end
  defp mount_board(board, socket) do

    if connected?(socket) do
      subscribe(board)
    end

    {:ok, assign(socket,
      body_class: get_color(board),  ## we set the body-class to avoid flickering
      board: board,
      current_user: fetch_user(socket),
      history: Issue.fetch_all(board),
      edit: false,
      menu: false,
      pop_over: nil,
      list_composer: Enum.empty?(board.lists))}
  end

  @doc """
  Handle different messages from live components and broadcast messages from other nodes
  """
  def handle_info(:preview_off, %Socket{assigns: %{original: original, preview: true}} = socket) do
    {:noreply, assign(socket, board: original, original: nil, preview: false)}
  end
  def handle_info(:preview_off, socket) do
    {:noreply, assign(socket, original: nil, preview: false)}
  end
  def handle_info({:preview, board}, %Socket{assigns: %{board: original}} = socket) do
    {:noreply, assign(socket, board: board, original: original, preview: true)}
  end
  def handle_info({:updated_board, board}, socket) do
    {:noreply, broadcast_update(socket, board)}
  end
  def handle_info(%{event: "update-board", payload: %{board: board, history: history}}, socket) do
    {:noreply, assign(socket, board: board, history: history)}
  end
  def handle_info(:close_all, socket) do
    {:noreply, close_other(socket)}
  end
  def handle_info({:close_menu_list, board}, socket) do
    socket = socket
             |> broadcast_update(board)
             |> close_other()
    {:noreply, socket}
  end
  defp close_other(%Socket{assigns: %{original: original, preview: true}} = socket) do
    assign(socket, board: original, original: nil, preview: false, pop_over: nil, menu: false, list_composer: false)
  end
  defp close_other(socket) do
    assign(socket, pop_over: nil, menu: false, list_composer: false)
  end
  @doc"""
  Handle all different events:

  * 'edit' turns the edit Title mode on
  * 'save' saves the title
  * 'move-list' moves a list within the board
  * 'move-list-to-end' moves a list to the end of all lists
  * 'move-card' moves a card within the same list or to other lists
  * 'move-card-to-end' moves a card to the end of a list
  """
  def handle_event("close-all", _params, socket) do
    {:noreply, close_other(socket)}
  end

  def handle_event("open-list-menu", %{"x" => x, "y" => y, "id" => id}, %Socket{assigns: %{current_user: user, board: board}} = socket) do
    with list when list != nil <- Board.find_list(board, id) do
      {:noreply, socket |> close_other() |> assign(pop_over: [id: :list_menu, current_user: user, board: board, list: list, x: x - 15, y: y + 15])}
    else
      _error -> {:noreply, socket}
    end
  end
  def handle_event("close-list-menu", _params, socket) do
    {:noreply, close_other(socket)}
  end
  def handle_event("open-menu", _value, socket) do
    {:noreply, socket |> close_other() |> assign(menu: true)}
  end
  def handle_event("close-menu", _value, socket) do
    {:noreply, assign(socket, menu: false)}
  end
  def handle_event("add-list", _value, socket) do
    {:noreply, socket |> close_other() |> assign(list_composer: true)}
  end
  def handle_event("cancel-add-list", _params, socket) do
    {:noreply, assign(socket, list_composer: false)}
  end
  def handle_event("save", %{"new_list" => %{"title" => title}},  %Socket{assigns: %{current_user: user, board: board}} = socket) do
    case title do
      ""     -> {:noreply, socket}
      _other ->
        board = Board.add_list(board, user, title)
        {:noreply, broadcast_update(socket, board, list_composer: false)}
    end
  end

  def handle_event("edit", _value, socket) do
    {:noreply, socket |> close_other() |> assign(:edit, true)}
  end

  def handle_event("save", %{"board" => %{"title" => new_title}}, %Socket{assigns: %{current_user: user, board: board}} = socket) do
    board = save_title(new_title, board, user)
    {:noreply, broadcast_update(socket, board, edit: false)}
  end
  def handle_event("save", %{"type" => "blur", "value" => new_title}, %Socket{assigns: %{current_user: user, board: board}} = socket) do
    board = save_title(new_title, board, user)
    {:noreply, broadcast_update(socket, board, edit: false)}
  end

  def handle_event("move-list", %{"id" => id, "before" => before_id}, %Socket{assigns: %{board: board, current_user: current_user}} = socket) do
    with list when list != nil               <- Board.find_list(board, id),
         before_list when before_list != nil <- Board.find_list(board, before_id) do

      board = Board.move_list(current_user, list, board, before_list)
      {:noreply, broadcast_update(socket, board)}
    else
      _error -> {:noreply, socket}
    end
  end

  def handle_event("move-list-to-end", id, %Socket{assigns: %{board: board, current_user: current_user}} = socket) do
    with list when list != nil <- Board.find_list(board, id) do

      board = Board.move_list(current_user, list, board, nil)
      {:noreply, broadcast_update(socket, board)}

    else
      _error -> {:noreply, socket}
    end
  end

  def handle_event("move-card", %{"id" => id, "to" => to_id, "from" => from_id, "before" => before_id},
                   %Socket{assigns: %{board: board, current_user: current_user}} = socket) do

    with to_list when to_list != nil         <- Board.find_list(board, to_id),
         from_list when from_list != nil     <- Board.find_list(board, from_id),
         card when card != nil               <- BoardList.find_card(from_list, id),
         before_card when before_card != nil <- BoardList.find_card(to_list, before_id) do

      board = Board.move_card_before(board, current_user, card, from_list, to_list, before_card)
      {:noreply, broadcast_update(socket, board)}
    else
      _error -> {:noreply, socket}
    end

  end

  def handle_event("move-card-to-end", %{"id" => id, "to" => to_id, "from" => from_id},
                   %Socket{assigns: %{board: board, current_user: current_user}} = socket) do

    with to_list when to_list != nil     <- Board.find_list(board, to_id),
         from_list when from_list != nil <- Board.find_list(board, from_id),
         card when card != nil           <- BoardList.find_card(from_list, id) do

      board = Board.move_card_to_end(board, current_user, card, from_list, to_list)
      {:noreply, broadcast_update(socket, board)}

    else
      _error -> {:noreply, socket}
    end

  end

  @doc """
  Render the live board
  """
  def render(assigns) do
    Phoenix.View.render(VegaWeb.BoardView, "board.html", assigns)
  end

  ##
  # save the new title only if the title was changed
  #
  defp save_title("", board, _user) do
    board
  end
  defp save_title(title, board, user) do
    case title == board.title do
      true  -> board
      false -> Board.set_title(board, user, title)
    end
  end

  ##
  # Subscribe the board
  #
  defp subscribe(board) do
    board
    |> topic()
    |> VegaWeb.Endpoint.subscribe()
  end

  ##
  # Broadcast an update of the board and returns the updated assigns for the socket
  #
  defp broadcast_update(socket, board, assigns \\ [])
  defp broadcast_update(socket, board, []) do
    history = Issue.fetch_all(board)
    VegaWeb.Endpoint.broadcast_from(self(), topic(board), "update-board", %{board: board, history: history})
    assign(socket, board: board, history: history, preview: false, original: nil)
  end
  defp broadcast_update(socket, board, assigns) do
    history = Issue.fetch_all(board)
    VegaWeb.Endpoint.broadcast_from(self(), topic(board), "update-board", %{board: board, history: history})
    socket
    |> assign(board: board, history: history, preview: false, original: nil)
    |> assign(assigns)
  end

  ##
  # Create the topic of the board
  #
  defp topic(%Board{_id: id}), do: "board:#{BSON.ObjectId.encode!(id)}"

end