defmodule VegaWeb.PageView do
  use VegaWeb, :view

  alias Vega.Issue
  alias Vega.Issue.NewCard
  alias Vega.Issue.SetDescription
  alias Vega.Issue.AddComment
  alias Vega.Issue.SetTitle
  alias Vega.Issue.AddList
  alias Vega.Issue.DeleteList
  alias Vega.Issue.ReorderList
  alias Vega.Issue.SortCards
  alias Vega.Issue.MoveCard
  alias Vega.Dates

  def make_id(prefix,id) do
    ["#", prefix, BSON.ObjectId.encode!(id)]
  end

  def make_card_id(id) do
    ["#card-", BSON.ObjectId.encode!(id)]
  end

  def make_list_id(id) do
    ["#list-", BSON.ObjectId.encode!(id)]
  end

  def make_text_id(id) do
    ["#text-", BSON.ObjectId.encode!(id)]
  end

  def id(id) do
    BSON.ObjectId.encode!(id)
  end

  def author(issue) do
    with user when user != nil <- Issue.author(issue) do
      [user.firstname, " ", user.lastname]
    else
      _error -> ["??"]
    end
  end

  def pretty_issue(%NewCard{title: title}) do
    ["added a new card with the title '", title, "'"]
  end
  def pretty_issue(%AddList{title: title}) do
    ["added a new list with the title '", title, "'"]
  end
  def pretty_issue(%ReorderList{order: _order}) do
    ["moved a list"]
  end
  def pretty_issue(%MoveCard{src: _src, dest: _src}) do
    ["moved a card"]
  end
  def pretty_issue(_other) do
    "??"
  end

  @doc"""
  Render a relative date format.

  ## Example

    iex> relative_date(date)
    "yesterday"

  """
  def relative_date(date) do
    days = date |> Dates.to_local() |> Timex.diff(Timex.now(), :days) |> abs()
    case days do
      0 -> format_hours(date)
      1 -> "yesterday"
      2 -> "the day before yesterday"
      x when x > 30 -> "30+ days ago"
      x -> [to_string(x), " days ago"]
    end
  end

  def format_hours(date) do
    hours = date |> Dates.to_local() |> Timex.diff(Timex.now(), :hours) |> abs()
    case hours do
      0 -> format_minutes(date)
      1 -> "an hour ago"
      x -> [to_string(x), " hours ago"]
    end
  end

  def format_minutes(date) do
    minutes = date |> Dates.to_local() |> Timex.diff(Timex.now(), :minutes) |> abs()
    case minutes do
      0 -> "few seconds ago"
      1 -> "one minute ago"
      x -> [to_string(x), " minutes ago"]
    end
  end
end
