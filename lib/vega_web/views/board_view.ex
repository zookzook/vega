defmodule VegaWeb.BoardView do

  use VegaWeb, :view

  alias Vega.Issue
  alias Vega.Dates
  alias Vega.BoardList
  alias Vega.WarningColorRule

  def has_title(nil), do: false
  def has_title(title), do: byte_size(title) > 2

  # todo: refactor validation functions
  def validate_title(nil), do: false
  def validate_title(title), do: byte_size(title) > 2

  @doc """
  Validate the selected list in case of moving cards to another list. The target list should be different.
  """
  def validate_selected_list(%BoardList{id: id}, other_id) do
    id != other_id
  end

  def is_active(this, that) do
    case this == that do
      true  -> "is-active"
      false -> []
    end
  end
  def is_selected(this, that) do
    case this == that do
      true  -> "selected"
      false -> []
    end
  end
  ## todo: not necessary any more
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

  @doc """
  Display the number of cards
  """
  def count_cards(%BoardList{n_cards: 0}) do
    gettext("0 cards")
  end
  def count_cards(%BoardList{n_cards: 1}) do
    gettext("one card")
  end
  def count_cards(%BoardList{n_cards: n}) do
    gettext("%{n} cards", n: n)
  end

  def fetch_color(%BoardList{n_cards: n, color: color}) do
    WarningColorRule.calc_color(color, n)
  end

  def warning_message(%BoardList{n_cards: n, color: %WarningColorRule{n: max}}) do
    case n > max do
      true  -> gettext(", more than %{n} cards", n: max)
      false -> []
    end
  end
  def warning_message(_other) do
    []
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
end
