defmodule VegaWeb.Auth do

  @moduledoc false

  import Plug.Conn

  alias Vega.User

  def init(opts), do: opts

  def call(conn, _opts) do
    #user_id = get_session(conn, :user_id)
    assign(conn, :current_user, User.fetch())
  end
end
