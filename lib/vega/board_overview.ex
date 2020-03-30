defmodule Vega.BoardOverview do
  @moduledoc """
  The module is used to fetch the title of the boards connected to the user. It only fetches some attributes (title, background color and the id) of each board.
  """

  @collection "boards"

  alias Vega.User

  @doc """
  Fetch all boards which are connected to the user:
  * personal boards
  * visited boards
  * starred boards
  """
  def fetch_all_for_user(nil) do
    {[], [], []}
  end
  def fetch_all_for_user(%User{_id: id}) do

    personal = :mongo
               |> Mongo.find(@collection, %{"members.id" => id}, projection: %{title: 1, options: 1})
               |> Enum.to_list()
               |> transform()

    {personal, [], []}
  end

  defp transform(boards) when is_list(boards) do
    Enum.map(boards, fn board -> transform(board) end)
  end
  defp transform(%{"_id" => id} = board) do
    Map.put(board, :id, BSON.ObjectId.encode!(id))
  end

end
