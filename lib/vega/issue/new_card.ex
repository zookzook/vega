defmodule Vega.Issue.NewCard do

  alias Vega.Issue.NewCard

  @mod Vega.IssueConsts.encode(:new_card)

  defstruct title: "", m: @mod

  def new(title) do
    %NewCard{title: title}
  end

  def to_struct(%{"m" => @mod, "title" => title}) do
    %NewCard{title: title}
  end

end