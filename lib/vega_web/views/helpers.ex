defmodule VegaWeb.Views.Helpers do

  @moduledoc """
  Conveniences for working with boards, lists and cards.
  """

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

end