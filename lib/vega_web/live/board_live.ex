defmodule VegaWeb.BoardLive do
  use Phoenix.LiveView

  alias Vega.Board
  alias Vega.User
  alias Vega.Issue
  alias Vega.BoardList
  alias Phoenix.LiveView.Socket

  def mount(_params, session, socket) do

    set_locale(session)

    current_user = User.fetch()

    board = case Board.fetch_one() do
      nil -> create_example_board(current_user)
      other -> other
    end

    current_user = User.fetch()
    history = Issue.fetch_all(board)
    {:ok, assign(socket, board: board, current_user: current_user, edit: false, history: history)}
  end

  def set_locale(session) do
    locale = session["locale"] || "en"
    Gettext.put_locale(locale)
    Vega.Cldr.put_locale(locale)
  end

  def handle_info({:updated_board, board}, socket) do
    {:noreply, assign(socket, board: board, history: Issue.fetch_all(board))}
  end

  def handle_event("new", _value, %Socket{assigns: assigns} = socket) do

    Mongo.delete_many(:mongo, "cards", %{})
    Mongo.delete_many(:mongo, "issues", %{})
    Mongo.delete_many(:mongo, "boards", %{})

    board = create_example_board(assigns.current_user)
    {:noreply, assign(socket, board: board, history: Issue.fetch_all(board))}
  end

  def handle_event("edit", _value, socket) do
    {:noreply, assign(socket, :edit, true)}
  end

  def handle_event("save", %{"board" => %{"title" => new_title}}, %Socket{assigns: %{board: board}} = socket) do
    board = save_title(new_title, board)
    history = Issue.fetch_all(board)
    {:noreply, assign(socket, board: board, edit: false, history: history)}
  end
  def handle_event("save", %{"type" => "blur", "value" => new_title}, %Socket{assigns: %{board: board}} = socket) do
    board = save_title(new_title, board)
    {:noreply, assign(socket, board: board, edit: false, history: Issue.fetch_all(board))}
  end

  def handle_event("move-list", %{"id" => id, "before" => before_id}, %Socket{assigns: %{board: board, current_user: current_user}} = socket) do
    with list when list != nil               <- Board.find_list(board, id),
         before_list when before_list != nil <- Board.find_list(board, before_id) do
      board = Board.move_list_before(board, current_user, list, before_list)
      {:noreply, assign(socket, board: board, history: Issue.fetch_all(board))}
    else
      _error -> {:noreply, socket}
    end
  end

  def handle_event("move-list-to-end", id, %Socket{assigns: %{board: board, current_user: current_user}} = socket) do
    with list when list != nil <- Board.find_list(board, id) do
      board = Board.move_list_to_end(board, current_user, list)
      {:noreply, assign(socket, board: board, history: Issue.fetch_all(board))}
    else
      _error ->
        {:noreply, socket}
    end
  end

  def handle_event("move-card", %{"id" => id, "to" => to_id, "from" => from_id, "before" => before_id} = params,
                   %Socket{assigns: %{board: board, current_user: current_user}} = socket) do

    IO.puts inspect params
    with to_list when to_list != nil         <- Board.find_list(board, to_id),
         from_list when from_list != nil     <- Board.find_list(board, from_id),
         card when card != nil               <- BoardList.find_card(from_list, id),
         before_card when before_card != nil <- BoardList.find_card(to_list, before_id) do
      board = Board.move_card_before(board, current_user, card, from_list, to_list, before_card)
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
      board = Board.move_card_to_end(board, current_user, card, from_list, to_list)
      {:noreply, assign(socket, board: board, history: Issue.fetch_all(board))}
    else
      _error -> {:noreply, socket}
    end

  end

  def render(assigns) do
    Phoenix.View.render(VegaWeb.PageView, "board.html", assigns)
  end

  defp save_title("", board) do
    board
  end
  defp save_title(title, board) do
    case title == board.title do
      true  -> board
      false -> Board.set_title(board, User.fetch(), title)
    end
  end

  defp create_example_board(user) do

    title = "A board title"
    board = Board.new(user, title)

    board = Board.add_list(board, user, "to do")
    board = Board.add_list(board, user, "doing")
    Board.add_list(board, user, "done")
  end

end