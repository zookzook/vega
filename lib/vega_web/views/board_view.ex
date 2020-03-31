defmodule VegaWeb.BoardView do
  use VegaWeb, :view


  def has_title(nil), do: false
  def has_title(title), do: byte_size(title) > 2

  def is_active(this, that) do
    case this == that do
      true  -> "is-active"
      false -> []
    end
  end
end
