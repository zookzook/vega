defmodule VegaWeb.BoardLive do
  use Phoenix.LiveView

  alias Vega.Board
  alias Vega.User
  alias Vega.Issue
  alias Vega.BoardList
  alias Phoenix.LiveView.Socket

  def mount(_params, session, socket) do

    set_locale(session)
    current_user = User.fetch(session["user_id"])

    board = case Board.fetch_one() do
      nil   -> create_example_board(current_user)
      other -> other
    end

    if connected?(socket), do: subscribe(board)

    history = Issue.fetch_all(board)
    {:ok, assign(socket, board: board, current_user: current_user, edit: false, history: history)}
  end

  @doc """
  Handle different messages from live components and broadcast messages from other nodes
  """
  def handle_info({:updated_board, board}, socket) do
    {:noreply, assign(socket, board: broadcast_update(board), history: Issue.fetch_all(board))}
  end
  def handle_info(%{event: "update-board", payload: board}, socket) do
    {:noreply, assign(socket, board: board, history: Issue.fetch_all(board))}
  end

  @doc"""
  Handle all different events:

  * 'new' create a new Board (and delete the others)
  * 'edit' turns the edit Title mode on
  * 'save' saves the title
  * 'move-list' moves a list within the board
  * 'move-list-to-end' moves a list to the end of all lists
  * 'move-card' moves a card within the same list or to other lists
  * 'move-card-to-end' moves a card to the end of a list
  """
  def handle_event("new", _value, %Socket{assigns: assigns} = socket) do

    Mongo.delete_many(:mongo, "cards", %{})
    Mongo.delete_many(:mongo, "issues", %{})
    Mongo.delete_many(:mongo, "boards", %{})

    board = create_example_board(assigns.current_user)
    {:noreply, assign(socket, board: broadcast_update(board), history: Issue.fetch_all(board))}
  end

  def handle_event("edit", _value, socket) do
    {:noreply, assign(socket, :edit, true)}
  end

  def handle_event("save", %{"board" => %{"title" => new_title}}, %Socket{assigns: %{current_user: user, board: board}} = socket) do
    board = save_title(new_title, board, user)
    history = Issue.fetch_all(board)
    {:noreply, assign(socket, board: broadcast_update(board), edit: false, history: history)}
  end
  def handle_event("save", %{"type" => "blur", "value" => new_title}, %Socket{assigns: %{current_user: user, board: board}} = socket) do
    board = save_title(new_title, board, user)
    {:noreply, assign(socket, board: broadcast_update(board), edit: false, history: Issue.fetch_all(board))}
  end

  def handle_event("move-list", %{"id" => id, "before" => before_id}, %Socket{assigns: %{board: board, current_user: current_user}} = socket) do
    with list when list != nil               <- Board.find_list(board, id),
         before_list when before_list != nil <- Board.find_list(board, before_id) do

      board = board |> Board.move_list_before(current_user, list, before_list) |> broadcast_update()
      {:noreply, assign(socket, board: board, history: Issue.fetch_all(board))}

    else
      _error -> {:noreply, socket}
    end
  end

  def handle_event("move-list-to-end", id, %Socket{assigns: %{board: board, current_user: current_user}} = socket) do
    with list when list != nil <- Board.find_list(board, id) do

      board = board |> Board.move_list_to_end(current_user, list) |> broadcast_update()
      {:noreply, assign(socket, board: board, history: Issue.fetch_all(board))}

    else
      _error -> {:noreply, socket}
    end
  end

  def handle_event("move-card", %{"id" => id, "to" => to_id, "from" => from_id, "before" => before_id} = params,
                   %Socket{assigns: %{board: board, current_user: current_user}} = socket) do

    with to_list when to_list != nil         <- Board.find_list(board, to_id),
         from_list when from_list != nil     <- Board.find_list(board, from_id),
         card when card != nil               <- BoardList.find_card(from_list, id),
         before_card when before_card != nil <- BoardList.find_card(to_list, before_id) do

      board = board |> Board.move_card_before(current_user, card, from_list, to_list, before_card) |> broadcast_update()
      {:noreply, assign(socket, board: board, history: Issue.fetch_all(board))}

    else
      _error -> {:noreply, socket}
    end

  end

  def handle_event("move-card-to-end", %{"id" => id, "to" => to_id, "from" => from_id},
                   %Socket{assigns: %{board: board, current_user: current_user}} = socket) do

    with to_list when to_list != nil     <- Board.find_list(board, to_id),
         from_list when from_list != nil <- Board.find_list(board, from_id),
         card when card != nil           <- BoardList.find_card(from_list, id) do

      board = board |> Board.move_card_to_end(current_user, card, from_list, to_list) |> broadcast_update()
      {:noreply, assign(socket, board: board, history: Issue.fetch_all(board))}

    else
      _error -> {:noreply, socket}
    end

  end

  @doc """
  Render the live board
  """
  def render(assigns) do
    Phoenix.View.render(VegaWeb.PageView, "board.html", assigns)
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
  # Create a simple sample board
  #
  defp create_example_board(user) do

    title = "Vega"
    board = Board.new(user, title)

    board = Board.add_list(board, user, "To do")
    board = Board.add_list(board, user, "Doing")
    Board.add_list(board, user, "Done")
  end

  ##
  # Set the locale
  #
  defp set_locale(session) do
    locale = session["locale"] || "en"
    Gettext.put_locale(locale)
    Vega.Cldr.put_locale(locale)
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
  # Broadcast an update of the board
  #
  defp broadcast_update(board) do
    VegaWeb.Endpoint.broadcast_from(self(), topic(board), "update-board", board)
    board
  end

  ##
  # Create the topic of the board
  #
  defp topic(%Board{_id: id}), do: "board:#{BSON.ObjectId.encode!(id)}"

end