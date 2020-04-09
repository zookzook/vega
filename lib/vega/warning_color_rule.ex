defmodule Vega.WarningColorRule do
  @moduledoc false

  alias Vega.WarningColorRule

  defstruct [
    :color,    ## the default color
    :n,        ## threshold
    :warning   ## the warning color
  ]

  def new(color, n, warning) do
    %WarningColorRule{color: color, n: n, warning: warning}
  end

  def calc_color(nil, _n) do
    []
  end
  def calc_color(%WarningColorRule{color: "default", n: max, warning: warning}, n) do
    case n > max do
      true  -> warning
      false -> []
    end
  end
  def calc_color(%WarningColorRule{color: color, n: max, warning: warning}, n) do
    case n > max do
      true  -> warning
      false -> color
    end
  end

  def to_struct(nil) do
    nil
  end
  def to_struct(%{"color" => color, "n" => n, "warning" => warning}) do
    %WarningColorRule{color: color, n: n, warning: warning}
  end
end