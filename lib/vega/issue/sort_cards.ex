defmodule Vega.Issue.SortCards do

  alias Vega.Issue.SortCards

  @sort_cards Vega.IssueConsts.encode(:sort_cards)

  defstruct style: "asc", m:  @sort_cards

  def new(style) do
    %SortCards{style: style}
  end

  def to_struct(%{"m" => @sort_cards, "style" => style}) do
    %SortCards{style: style}
  end
end