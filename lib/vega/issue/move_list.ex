defmodule Vega.Issue.MoveList do

  alias Vega.Issue.MoveList

  @move_list Vega.IssueConsts.encode(:move_list)

  defstruct m: @move_list

  def new() do
    %MoveList{}
  end

  def to_struct(%{"m" => @move_list}) do
    %MoveList{}
  end
end