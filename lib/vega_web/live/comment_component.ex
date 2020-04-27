defmodule Vega.CommentComponent do
  @moduledoc false

  use VegaWeb, :component

  def render(assigns) do
    Phoenix.View.render(VegaWeb.CardView, "comment.html", assigns)
  end

end
