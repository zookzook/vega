defmodule VegaWeb.Router do
  use VegaWeb, :router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug VegaWeb.Auth
  end

  pipeline :live_pipe do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug VegaWeb.Auth
    plug :put_live_layout, {VegaWeb.LayoutView, "app.html"}
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
    live "/", BoardLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", VegaWeb do
  #   pipe_through :api
  # end
end
