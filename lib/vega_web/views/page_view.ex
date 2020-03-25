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
      1 -> gettext("yesterday")
      2 -> gettext("the day before yesterday")
      x ->
        {:ok, result} = Vega.Cldr.DateTime.to_string(date, format: :y_mm_md)
        result
    end
  end

  def format_hours(date) do
    hours = date |> Dates.to_local() |> Timex.diff(Timex.now(), :hours) |> abs()
    case hours do
      0 -> format_minutes(date)
      1 -> gettext("an hour ago")
      x -> gettext("%{t} hours ago", t: to_string(x))
    end
  end

  def format_minutes(date) do
    minutes = date |> Dates.to_local() |> Timex.diff(Timex.now(), :minutes) |> abs()
    case minutes do
      0 -> gettext("few seconds ago")
      1 -> gettext("one minute ago")
      x -> gettext("%{t} minutes ago", t: to_string(x))
    end
  end
end
