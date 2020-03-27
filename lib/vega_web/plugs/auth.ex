defmodule Vega.Plugs.Auth do

  @moduledoc false

  import Plug.Conn

  alias Phoenix.Controller
  alias Vega.User

  def init(opts), do: opts

  def call(conn, _opts) do

    conn
    |> get_session(:user_id)
    |> User.fetch()
    |> maybe_halt(conn)
  end

  defp maybe_halt(nil, conn) do
    conn
    |> Controller.redirect(to: "/")
    |> halt()
  end
  defp maybe_halt(_user, conn), do: conn

end
