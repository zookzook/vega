defmodule Vega.Member do
  @moduledoc false

  use Yildun.Collection

  alias Vega.Member
  alias Vega.User

  document do
    attribute :role, String.t(), default: "admin"     ## name of the role
    attribute :id, BSON.ObjectId.t()                  ## user id
  end

  def new(%User{_id: id}) do
    %Member{new() | id: id}
  end
end