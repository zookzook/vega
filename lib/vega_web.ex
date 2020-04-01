defmodule VegaWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use VegaWeb, :controller
      use VegaWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: VegaWeb

      import Plug.Conn
      import VegaWeb.Gettext
      alias VegaWeb.Router.Helpers, as: Routes
      import Phoenix.LiveView.Controller
      alias Plug.Conn

      defp fetch_user(%Conn{assigns: %{current_user: user}}) do
        user
      end
      defp fetch_user(_other) do
        nil
      end

      defp assign_asserts(conn, assert) do
        merge_assigns(conn, css: [assert], js: [assert])
      end
    end
  end

  def live do
    quote do
      use Phoenix.LiveView

      alias VegaWeb.Router.Helpers, as: Routes
      alias Phoenix.LiveView.Socket
      alias Vega.User

      ##
      # Set the locale
      #
      defp set_locale(session) do
        locale = session["locale"] || "en"
        Gettext.put_locale(locale)
        Vega.Cldr.put_locale(locale)
        session
      end

      ##
      # fetch the user from session or socket assigns
      #
      defp fetch_user(%{"user_id" => user_id}, socket) do
        assign(socket, current_user: User.fetch(user_id))
      end
      defp fetch_user(%Socket{assigns: assigns}) do
        assigns.current_user
      end

      defp assign_asserts(socket, assert) do
        assign(socket, css: [assert], js: [assert])
      end
    end
  end

  def component do
    quote do
      use Phoenix.LiveComponent

      alias Phoenix.LiveView.Socket
      alias Vega.Board
      alias Vega.User

      ##
      # fetch the user from socket assigns
      #
      defp fetch_user(%Socket{assigns: assigns}) do
        assigns.current_user
      end

      defp fetch_board(%Socket{assigns: assigns}) do
        assigns.board
      end

    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/vega_web/templates",
        namespace: VegaWeb

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_flash: 1, get_flash: 2, view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      import VegaWeb.ErrorHelpers
      import VegaWeb.Gettext
      alias VegaWeb.Router.Helpers, as: Routes
      import Phoenix.LiveView.Helpers
      import VegaWeb.Views.Helpers
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import VegaWeb.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
