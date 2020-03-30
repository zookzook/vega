defmodule VegaWeb.Router do
  use VegaWeb, :router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Vega.Plugs.SetLocale
    plug Vega.Plugs.FetchUser
    plug :put_root_layout, {VegaWeb.LayoutView, :root}
  end

  pipeline :live_pipe do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Vega.Plugs.SetLocale
    plug Vega.Plugs.Auth
    plug :put_root_layout, {VegaWeb.LayoutView, :root}
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", VegaWeb do
    pipe_through :browser
    get "/", PageController, :index
  end

  scope "/board", VegaWeb do
    pipe_through :live_pipe

    live "/new", NewBoardLive
    live "/:id", BoardLive
  end

  scope "/auth", VegaWeb do
    pipe_through :browser

    get "/logout", AuthController, :delete
    get "/fake", AuthController, :fake
    get "/:provider", AuthController, :index
    get "/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :delete
  end

  # Other scopes may use custom stacks.
  # scope "/api", VegaWeb do
  #   pipe_through :api
  # end
end
