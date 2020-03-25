defmodule Vega.Issues do

  import VegaWeb.Gettext

  alias Vega.IssueConsts
  alias Vega.Issue
  alias Vega.Issue.NewCard
  alias Vega.Issue.SetDescription
  alias Vega.Issue.AddComment
  alias Vega.Issue.SetTitle
  alias Vega.Issue.AddList
  alias Vega.Issue.DeleteList
  alias Vega.Issue.SortCards
  alias Vega.Issue.MoveCard
  alias Vega.Issue.MoveList

  @new_card        IssueConsts.encode(:new_card)
  @set_description IssueConsts.encode(:set_description)
  @add_comment     IssueConsts.encode(:add_comment)
  @set_title       IssueConsts.encode(:set_title)
  @add_list        IssueConsts.encode(:add_list)
  @delete_list     IssueConsts.encode(:delete_list)
  @sort_cards      IssueConsts.encode(:sort_cards)
  @move_card       IssueConsts.encode(:move_card)
  @move_list       IssueConsts.encode(:move_list)

  def to_struct(%{"t" => %{"m" => @new_card} = mod} = issue) do
    %Issue{transform(issue) | t: NewCard.to_struct(mod)} |> add_msg(@new_card)
  end
  def to_struct(%{"t" => %{"m" => @set_description} = mod} = issue) do
    %Issue{transform(issue) | t: SetDescription.to_struct(mod)} |> add_msg(@set_description)
  end
  def to_struct(%{"t" => %{"m" => @add_comment} = mod} = issue) do
    %Issue{transform(issue) | t: AddComment.to_struct(mod)} |> add_msg(@add_comment)
  end
  def to_struct(%{"t" => %{"m" => @set_title} = mod} = issue) do
    %Issue{transform(issue) | t: SetTitle.to_struct(mod)} |> add_msg(@set_title)
  end
  def to_struct(%{"t" => %{"m" => @add_list} = mod} = issue) do
    %Issue{transform(issue) | t: AddList.to_struct(mod)} |> add_msg(@add_list)
  end
  def to_struct(%{"t" => %{"m" => @delete_list} = mod} = issue) do
    %Issue{transform(issue) | t: DeleteList.to_struct(mod)} |> add_msg(@delete_list)
  end
  def to_struct(%{"t" => %{"m" => @sort_cards} = mod} = issue) do
    %Issue{transform(issue) | t: SortCards.to_struct(mod)} |> add_msg(@sort_cards)
  end
  def to_struct(%{"t" => %{"m" => @move_card} = mod} = issue) do
    %Issue{transform(issue) | t: MoveCard.to_struct(mod)} |> add_msg(@move_card)
  end
  def to_struct(%{"t" => %{"m" => @move_list} = mod} = issue) do
    %Issue{transform(issue) | t: MoveList.to_struct(mod)} |> add_msg(@move_list)
  end

  defp transform(issue) do
    %Issue{_id: issue["_id"], ts: issue["ts"], author_id: issue["author_id"], board: issue["board"], list: issue["list"], keys: issue["keys"] || []}
  end

  ##
  # set the title of a board
  #
  defp add_msg(issue, @set_title) do
    %Issue{issue | msg: gettext("changed title '%{title}' of board '%{board}'", map_to_keywords(issue.keys))}
  end
  ##
  # Create a new list
  #
  defp add_msg(issue, @add_list) do
    %Issue{issue | msg: gettext("added a new list '%{title}' to board '%{board}'", map_to_keywords(issue.keys))}
  end
  ##
  # Create a new card
  #
  defp add_msg(issue, @new_card) do
    %Issue{issue | msg: gettext("added a new card with title '%{title}' to list '%{list}'", map_to_keywords(issue.keys))}
  end
  ##
  # Move a card
  #
  defp add_msg(issue, @move_card) do
    case Map.has_key?(issue.keys, "b") do
      true  -> %Issue{issue | msg: gettext("moved card '%{a}' in front of '%{b}'", map_to_keywords(issue.keys))}
      false -> %Issue{issue | msg: gettext("moved card '%{a}' to the end", map_to_keywords(issue.keys))}
    end
  end
  ##
  # Move a card
  #
  defp add_msg(issue, @move_list) do
    case Map.has_key?(issue.keys, "b") do
      true  -> %Issue{issue | msg: gettext("moved list '%{a}' in front of '%{b}'", map_to_keywords(issue.keys))}
      false -> %Issue{issue | msg: gettext("moved list '%{a}' to the end", map_to_keywords(issue.keys))}
    end
  end
  ##
  # Catch-All function
  #
  defp add_msg(issue, type) do
    %Issue{issue | msg: to_string(type) <> "-??"}
  end

  defp map_to_keywords(keys) do
    Enum.map(keys, fn({key, value}) -> {String.to_existing_atom(key), value} end)
  end

end
