defmodule Vega.Issue.SetTitle do

  alias Vega.Issue.SetTitle

  @mod Vega.IssueConsts.encode(:set_title)

  defstruct title: "", m: @mod

  def new(title) do
    %SetTitle{title: title}
  end

  def to_struct(%{"m" => @mod, "title" => title}) do
    %SetTitle{title: title}
  end

end