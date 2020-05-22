defmodule VegaWeb.CardView do

  use VegaWeb, :view

  alias Vega.Dates

  alias Vega.Comment
  alias Vega.User

  ## todo: put this into a utils module
  def markdown(string) do
    with {:ok, html_doc, []} <- Earmark.as_html(string) do
      html_doc
    end
  end

  def author(%Comment{} = comment) do
    with user when user != nil <- User.get(comment) do
      user.name
    else
      _error -> ["??"]
    end
  end

  ## todo: put this into a utils module
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