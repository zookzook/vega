defmodule Vega.Issue.MoveCard do

  alias Vega.Issue.MoveCard

  @move_card Vega.IssueConsts.encode(:move_card)

  defstruct src: nil, dest: nil, m:  @move_card

  def new(src) do
    %MoveCard{src: src, dest: src}
  end
  def new(src, dest) do
    %MoveCard{src: src, dest: dest}
  end

  def to_struct(%{"m" => @move_card, "src" => src, "dest" => dest}) do
    %MoveCard{src: src, dest: dest}
  end
end