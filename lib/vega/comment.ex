defmodule Vega.Comment do

  use Yildun.Collection

  alias Vega.User
  alias Vega.Comment

  document do
    attribute :_id, BSON.ObjectID.t(), default: &Mongo.object_id/0  ## the ObjectId of the card
    attribute :id, String.t(), derived: true                        ## the ObjectId as string, delegate: BSON.ObjectId.encode!/1
    attribute :text, String.t()                                     ## the comment
    attribute :user, BSON.ObjectID.t()                              ## the user id of the author
    attribute :created, DateTime.t(), default: &DateTime.utc_now/0  ## creation date

    after_load  &Comment.after_load/1
  end

  def new(comment, %User{_id: id}) do
    new()
    |> Map.put(:text, comment)
    |> Map.put(:user, id)
  end

  def after_load(%Comment{_id: id} = comment) do
    Map.put(comment, :id, BSON.ObjectId.encode!(id))
  end
end