defmodule Vega.Issues do

  alias Vega.IssueConsts
  alias Vega.Issue
  alias Vega.Issue.NewCard
  alias Vega.Issue.SetDescription
  alias Vega.Issue.AddComment
  alias Vega.Issue.SetTitle
  alias Vega.Issue.AddList
  alias Vega.Issue.DeleteList
  alias Vega.Issue.ReorderList
  alias Vega.Issue.SortCards
  alias Vega.Issue.MoveCard

  @new_card        IssueConsts.encode(:new_card)
  @set_description IssueConsts.encode(:set_description)
  @add_comment     IssueConsts.encode(:add_comment)
  @set_title       IssueConsts.encode(:set_title)
  @add_list        IssueConsts.encode(:add_list)
  @delete_list     IssueConsts.encode(:delete_list)
  @reorder_list    IssueConsts.encode(:reorder_list)
  @sort_cards      IssueConsts.encode(:sort_cards)
  @move_card       IssueConsts.encode(:move_card)

  def to_struct(%{"t" => %{"m" => @new_card} = mod} = issue) do
    %Issue{transform(issue) | t: NewCard.to_struct(mod)}
  end
  def to_struct(%{"t" => %{"m" => @set_description} = mod} = issue) do
    %Issue{transform(issue) | t: SetDescription.to_struct(mod)}
  end
  def to_struct(%{"t" => %{"m" => @add_comment} = mod} = issue) do
    %Issue{transform(issue) | t: AddComment.to_struct(mod)}
  end
  def to_struct(%{"t" => %{"m" => @set_title} = mod} = issue) do
    %Issue{transform(issue) | t: SetTitle.to_struct(mod)}
  end
  def to_struct(%{"t" => %{"m" => @add_list} = mod} = issue) do
    %Issue{transform(issue) | t: AddList.to_struct(mod)}
  end
  def to_struct(%{"t" => %{"m" => @delete_list} = mod} = issue) do
    %Issue{transform(issue) | t: DeleteList.to_struct(mod)}
  end
  def to_struct(%{"t" => %{"m" => @reorder_list} = mod} = issue) do
    %Issue{transform(issue) | t: ReorderList.to_struct(mod)}
  end
  def to_struct(%{"t" => %{"m" => @sort_cards} = mod} = issue) do
    %Issue{transform(issue) | t: SortCards.to_struct(mod)}
  end
  def to_struct(%{"t" => %{"m" => @move_card} = mod} = issue) do
    %Issue{transform(issue) | t: MoveCard.to_struct(mod)}
  end
  defp transform(issue) do
    %Issue{_id: issue["_id"], ts: issue["ts"], author_id: issue["author_id"], board: issue["board"]}
  end
end
