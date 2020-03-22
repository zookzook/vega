defmodule Vega.Issue.ReorderList do

  alias Vega.Issue.ReorderList

  @reorder_list Vega.IssueConsts.encode(:reorder_list)

  defstruct order: [], m:  @reorder_list

  def new(order) do
    %ReorderList{order: order}
  end

  def to_struct(%{"m" => @reorder_list, "order" => order}) do
    %ReorderList{order: order}
  end
end