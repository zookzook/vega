defmodule Vega.Issue.AddList do

  alias Vega.Issue.AddList

  @add_list Vega.IssueConsts.encode(:add_list)

  defstruct title: "", m:  @add_list

  def new(title) do
    %AddList{title: title}
  end

  def to_struct(%{"m" => @add_list, "title" => title}) do
    %AddList{title: title}
  end
end