defmodule Vega.User do
  @moduledoc """

  This module describes the user struct.

  """

  alias Vega.User
  import Vega.StructHelper

  defstruct [
    :_id,         ## the id of the user
    :name,        ## Name
    :login,       ## login struct: a map with keys provider and login
    :email,       ## email - optional
    :avatar_url   ## avatar_url - optional
  ]

  @collection "users"

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
    |> to_struct()
  end

  def fetch(nil) do
    nil
  end
  def fetch(id) when is_binary(id) do
    fetch(BSON.ObjectId.decode!(id))
  end
  def fetch(id) do
    Mongo.find_one(:mongo, @collection, %{_id: id}) |> to_struct()
  end

  def fake(login) do
    user = %{
      "email" => "zookzook@unitybox.de",
      "name" => "Michael Maier",
      "login" => login
    }
    login_github(user)
  end

  def to_struct(nil) do
    nil
  end
  def to_struct(%{"_id" => id, "login" => login} = user) do
    %User{
      _id:        id,
      email:      user["email"],
      name:       user["name"],
      avatar_url: user["avatar_url"],
      login:      login
    }
  end

end
