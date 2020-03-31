defmodule VegaWeb.PageView do
  use VegaWeb, :view

  alias Vega.Issue
  alias Vega.Dates
  alias Vega.Board

  def get_color(%{"color" => color}) when not is_nil(color) do
    color
  end
  def get_color(%Board{options: nil}) do
    nil
  end
  def get_color(%Board{options: opts}) do
    Keyword.get(opts, :color)
  end
  def get_color(_other) do
    nil
  end

  def non_empty(xs) do
    not Enum.empty?(xs)
  end

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
      user.name
    else
      _error -> ["??"]
    end
  end

  def is_idle_class(true) do
    []
  end
  def is_idle_class(false) do
    "is-idle"
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
      _ ->
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

  def _translate() do
    gettext("Select color orange")
    gettext("Select color red")
    gettext("Select color blue")
    gettext("Select color green")
    gettext("Select color purple")
    gettext("Select color pink")
  end
end
