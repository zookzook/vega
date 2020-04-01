defmodule Vega.CardComponent do
  @moduledoc false

  use Phoenix.LiveComponent

  def render(assigns) do
    Phoenix.View.render(VegaWeb.BoardView, "card.html", assigns)
  end

end
