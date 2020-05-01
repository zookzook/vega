defmodule Vega.Comment do

  alias Vega.User
  alias Vega.Comment
  import Vega.StructHelper

  @derived_attributes [:id]

  defstruct [
    :_id,    ## the ObjectId of the card
    :id,     ## the ObjectId as string, delegate: BSON.ObjectId.encode!/1
    :text,   ## the comment
    :user,   ## the user id of the author
    :created ## creation date
  ]

  def new(comment, %User{_id: id}) do
    %Comment{_id: Mongo.object_id(), text: comment, user: id, created: DateTime.utc_now()}
  end

  def author(%Comment{user: user}) do
    User.fetch(user) ## todo caching system
  end

  def dump(%Comment{} = comment) do
    comment
    |> Map.drop(@derived_attributes)
    |> to_map()
  end

  def load(nil) do
    nil
  end
  def load(map) do
    id = map["_id"]
    %Comment{_id: id,
      id: BSON.ObjectId.encode!(id),
      text: map["text"],
      user: map["user"],
      created: map["created"]}
  end
end