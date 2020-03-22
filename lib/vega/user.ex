defmodule Vega.User do
  @moduledoc """

  This module describes the user struct.

  """

  alias Vega.User

  defstruct _id: nil, email: nil, firstname: nil, lastname: nil

  @collection "users"

  def new(email, firstname, lastname) do
    %User{_id: Mongo.object_id(), email: email, firstname: firstname, lastname: lastname}
  end

  def fetch() do
    case Mongo.find_one(:mongo, @collection, %{}) do
      nil ->
        result = new("zookzook@speckbert.de", "Michael", "Maier")
        Mongo.insert_one(:mongo, @collection, Map.from_struct(result))
        result
      user -> to_struct(User, user)
    end
  end

  ## todo: refactor this to one module
  defp to_struct(kind, attrs) do
    struct = struct(kind)

    struct
    |> Map.to_list()
    |> Enum.reduce(struct, fn {k, _}, acc ->
      case Map.fetch(attrs, Atom.to_string(k)) do
        {:ok, v} -> %{acc | k => v}
        :error   -> acc
      end
    end)

  end

end
