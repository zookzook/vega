defmodule Vega.WarningColorRule do
  @moduledoc false

  alias Vega.WarningColorRule

  defstruct [
    :color,    ## the default color
    :n,        ## threshold
    :warning   ## the warning color
  ]

  def new(color, n, warning) do
    %WarningColorRule{color: color, n: n, warning: warning} |> filter_default()
  end

  def calc_color(nil, _n) do
    []
  end
  def calc_color(%WarningColorRule{color: "default", n: max, warning: warning}, n) when max > 0 do
    case n > max do
      true  -> warning
      false -> []
    end
  end
  def calc_color(%WarningColorRule{color: color, n: max, warning: warning}, n) when max > 0 do
    case n > max do
      true  -> warning
      false -> color
    end
  end
  def calc_color(%WarningColorRule{color: color}, _n) do
    color
  end

  @doc """
  Filter default color rule. If the color and the warning color is "none", then
  the color rule has no effect, so it can be removed from the list.
  """
  def filter_default(%WarningColorRule{color: "none", n: _n, warning: "none"}) do
    nil
  end
  def filter_default(other) do
    other
  end

  def to_struct(nil) do
    nil
  end
  def to_struct(%{"color" => color, "n" => n, "warning" => warning}) do
    %WarningColorRule{color: color, n: n, warning: warning}
  end
end