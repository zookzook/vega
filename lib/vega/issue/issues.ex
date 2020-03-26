defmodule Vega.Issues do

  import VegaWeb.Gettext

  alias Vega.IssueConsts
  alias Vega.Issue

  @new_card        IssueConsts.encode(:new_card)
  @set_description IssueConsts.encode(:set_description)
  # todo: @add_comment     IssueConsts.encode(:add_comment)
  @set_title       IssueConsts.encode(:set_title)
  @add_list        IssueConsts.encode(:add_list)
  @delete_list     IssueConsts.encode(:delete_list)
  # todo: @sort_cards      IssueConsts.encode(:sort_cards)
  @move_card       IssueConsts.encode(:move_card)
  @move_list       IssueConsts.encode(:move_list)

  def to_struct(issue) do
    issue
    |> transform()
    |> add_msg()
  end

  defp transform(issue) do
    %Issue{_id: issue["_id"], ts: issue["ts"], author_id: issue["author_id"], board: issue["board"], t: issue["t"], list: issue["list"], keys: issue["keys"] || []}
  end

  ##
  # Set the title of a board
  #
  defp add_msg(%Issue{t: @set_title} = issue) do
    %Issue{issue | msg: gettext("changed title '%{title}' of board '%{board}'", map_to_keywords(issue.keys))}
  end
  ##
  # Set the description of a board
  #
  defp add_msg(%Issue{t: @set_description} = issue) do
    %Issue{issue | msg: gettext("changed the description '%{description}' of board '%{board}'", map_to_keywords(issue.keys))}
  end
  ##
  # Create a new list
  #
  defp add_msg(%Issue{t: @add_list} = issue) do
    %Issue{issue | msg: gettext("added a new list '%{title}' to board '%{board}'", map_to_keywords(issue.keys))}
  end
  ##
  # Delete a new list
  #
  defp add_msg(%Issue{t: @delete_list} = issue) do
    %Issue{issue | msg: gettext("deleted the list '%{title}' from board '%{board}'", map_to_keywords(issue.keys))}
  end
  ##
  # Create a new card
  #
  defp add_msg(%Issue{t: @new_card} = issue) do
    %Issue{issue | msg: gettext("added a new card with title '%{title}' to list '%{list}'", map_to_keywords(issue.keys))}
  end
  ##
  # Move a card
  #
  defp add_msg(%Issue{t: @move_card} = issue) do
    case {Map.has_key?(issue.keys, "list"), Map.has_key?(issue.keys, "b") } do
      {true, true}   -> %Issue{issue | msg: gettext("moved card '%{a}' in front of '%{b}' of list '%{list}", map_to_keywords(issue.keys))}
      {true, false}  -> %Issue{issue | msg: gettext("moved card '%{a}' to the end of list '%{list}'", map_to_keywords(issue.keys))}
      {false, true}  -> %Issue{issue | msg: gettext("moved card '%{a}' in front of '%{b}'", map_to_keywords(issue.keys))}
      {false, false} -> %Issue{issue | msg: gettext("moved card '%{a}' to the end", map_to_keywords(issue.keys))}
    end
  end
  ##
  # Move a card
  #
  defp add_msg(%Issue{t: @move_list} = issue) do
    case Map.has_key?(issue.keys, "b") do
      true  -> %Issue{issue | msg: gettext("moved list '%{a}' in front of '%{b}'", map_to_keywords(issue.keys))}
      false -> %Issue{issue | msg: gettext("moved list '%{a}' to the end", map_to_keywords(issue.keys))}
    end
  end
  ##
  # Catch-All function
  #
  defp add_msg(%Issue{t: type} = issue) do
    %Issue{issue | msg: to_string(type) <> "-??"}
  end

  defp map_to_keywords(keys) do
    Enum.map(keys, fn({key, value}) -> {String.to_existing_atom(key), value} end)
  end

end
