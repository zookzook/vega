defmodule Vega.Issue.DeleteList do

  alias Vega.Issue.DeleteList

  @delete_list Vega.IssueConsts.encode(:delete_list)

  defstruct title: "", m:  @delete_list

  def new(title) do
    %DeleteList{title: title}
  end

  def to_struct(%{"m" => @delete_list, "title" => title}) do
    %DeleteList{title: title}
  end
end