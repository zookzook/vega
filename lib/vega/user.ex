defmodule Vega.User do
  @moduledoc """

  This module describes the user struct.

  """

  use GenServer

  alias Vega.User
  alias Phoenix.PubSub
  import Vega.StructHelper

  defstruct [
    :_id,         ## the id of the user
    :name,        ## Name
    :login,       ## login struct: a map with keys provider and login
    :email,       ## email - optional
    :avatar_url   ## avatar_url - optional
  ]

  @collection "users"
  @topic "cache:users"

  def new_github(github_user) do
    %User{_id: Mongo.object_id(),
      email: github_user["email"],
      name: github_user["name"],
      avatar_url: github_user["avatar_url"],
      login: %{provider: "github", login: github_user["login"]}
    }
  end

  def login_github(github_user) do
    case fetch_github(github_user) do
      nil->
        user = new_github(github_user)
        with {:ok, _} <- Mongo.insert_one(:mongo, @collection, to_map(user)) do
          user
        end
      user -> user
    end
  end

  def fetch_github(github_user) do
    :mongo
    |> Mongo.find_one(@collection, %{"login.provider" => "github", "login.login" => github_user["login"]})
    |> load()
  end
  def fetch_by_login(login) do
    :mongo
    |> Mongo.find_one(@collection, %{"login.provider" => "github", "login.login" => login})
    |> load()
  end
  def fetch(nil) do
    nil
  end
  def fetch(id) when is_binary(id) do
    fetch(BSON.ObjectId.decode!(id))
  end
  def fetch(id) do
    Mongo.find_one(:mongo, @collection, %{_id: id}) |> load()
  end

  def fake(login, name, email) do
    user = %{
      "email" => email,
      "name" => name,
      "login" => login
    }
    login_github(user)
  end
  def fake(login) do
    fetch_by_login(login)
  end

  def dump(%User{} = user) do
    to_map(user)
  end

  def load(nil) do
    nil
  end
  def load(%{"_id" => id, "login" => login} = user) do
    %User{
      _id:        id,
      email:      user["email"],
      name:       user["name"],
      avatar_url: user["avatar_url"],
      login:      login
    }
  end

  def get(id) when is_binary(id) do
    case Cachex.fetch(:users, id) do
      {:ok, user} -> user
      _           -> nil
    end
  end
  def get(id) do
    id |> BSON.ObjectId.encode!() |> get()
  end

  def remove(ids) when is_list(ids) do
    Enum.each(ids, fn id -> Cachex.del(:users, id) end)
    PubSub.broadcast( Vega.PubSub, @topic, {:remove, ids})
  end

  def remove(id) do
    Cachex.del(:users, id)
    PubSub.broadcast(Vega.PubSub, @topic, {:remove, id})
  end

  def fallback(id) do
    with found when found != nil <- fetch(id) do
      {:commit, found}
    else
      _ -> {:ignore, :not_found}
    end
  end

  @me __MODULE__

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: @me)
  end

  def init(_) do
    PubSub.subscribe(Vega.PubSub, @topic)
    {:ok, []}
  end

  def handle_info({:remove, ids}, state) when is_list(ids) do
    Enum.each(ids, fn id -> Cachex.del(:users, id) end)
    {:noreply, state}
  end

  def handle_info({:remove, id}, state) do
    Cachex.del(:users, id)
    {:noreply, state}
  end

end
