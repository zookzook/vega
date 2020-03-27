defmodule Vega.Plugs.FetchUser do

  @moduledoc false

  import Plug.Conn

  alias Vega.User

  def init(opts), do: opts

  def call(conn, _opts) do

    conn
    |> get_session(:user_id)
    |> User.fetch()
    |> assign_user(conn)
  end

  defp assign_user(user, conn) do
    conn
    |> assign(:current_user, user)
  end

end