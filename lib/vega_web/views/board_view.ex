defmodule VegaWeb.BoardView do
  use VegaWeb, :view


  def has_title(nil), do: false
  def has_title(title), do: byte_size(title) > 3

  def is_active(color, color2) do
    case color == color2 do
      true  -> "board__is-active"
      false -> []
    end
  end
end
