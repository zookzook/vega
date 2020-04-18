defmodule Vega.Issues do

  import VegaWeb.Gettext

  alias Vega.IssueConsts
  alias Vega.Issue

  @new_board          IssueConsts.encode(:new_board)
  @new_card           IssueConsts.encode(:new_card)
  @set_description    IssueConsts.encode(:set_description)
  # todo: @add_comment     IssueConsts.encode(:add_comment)
  @set_title          IssueConsts.encode(:set_title)
  @set_board_color    IssueConsts.encode(:set_board_color)
  @add_list           IssueConsts.encode(:add_list)
  @delete_list        IssueConsts.encode(:delete_list)
  @sort_cards         IssueConsts.encode(:sort_cards)
  @move_card          IssueConsts.encode(:move_card)
  @move_list          IssueConsts.encode(:move_list)
  @copy_list          IssueConsts.encode(:copy_list)
  @set_list_color     IssueConsts.encode(:set_list_color)
  @move_cards_of_list IssueConsts.encode(:move_cards_of_list)
  @archive_list       IssueConsts.encode(:archive_list)

  def to_struct(issue) do
    issue
    |> transform()
    |> add_msg()
  end

  defp transform(issue) do
    %Issue{_id: issue["_id"], ts: issue["ts"], author_id: issue["author_id"], board: issue["board"], t: issue["t"], list: issue["list"], keys: issue["keys"] || []}
  end

  ##
  # Create a new board
  #
  defp add_msg(%Issue{t: @new_board} = issue) do
    %Issue{issue | msg: gettext("create a new board '%{title}'", map_to_keywords(issue.keys))}
  end
  ##
  # Set the color of a board
  #
  defp add_msg(%Issue{t: @set_board_color} = issue) do
    color = Gettext.gettext(VegaWeb.Gettext, issue.keys["color"])
    keys  = Map.put(issue.keys, "color", color)
    %Issue{issue | msg: gettext("changed the color of board '%{board}' to '%{color}'", map_to_keywords(keys))}
  end
  ##
  # Set the description of a board
  #
  defp add_msg(%Issue{t: @set_description} = issue) do
    %Issue{issue | msg: gettext("changed the description '%{description}' of board '%{board}'", map_to_keywords(issue.keys))}
  end
  ##
  # Set the title of a board
  #
  defp add_msg(%Issue{t: @set_title} = issue) do
    case Map.has_key?(issue.keys, "list") do
      true  -> %Issue{issue | msg: gettext("changed title '%{title}' of list '%{list}'", map_to_keywords(issue.keys))}
      false -> %Issue{issue | msg: gettext("changed title '%{title}' of board '%{board}'", map_to_keywords(issue.keys))}
    end
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
    case {Map.has_key?(issue.keys, "b"), Map.has_key?(issue.keys, "from"), Map.has_key?(issue.keys, "to")} do
      {true, _, _}  -> %Issue{issue | msg: gettext("moved list '%{a}' in front of '%{b}'", map_to_keywords(issue.keys))}
      {_, true, _}  -> %Issue{issue | msg: gettext("moved list '%{a}' from board '%{from}'", map_to_keywords(issue.keys))}
      {_, _, true}  -> %Issue{issue | msg: gettext("moved list '%{a}' to board '%{to}'", map_to_keywords(issue.keys))}
      _             -> %Issue{issue | msg: gettext("moved list '%{a}' to the end", map_to_keywords(issue.keys))}
    end
  end
  ##
  # Copy a list
  #
  defp add_msg(%Issue{t: @copy_list} = issue) do
    %Issue{issue | msg: gettext("copied the list '%{title}'", map_to_keywords(issue.keys))}
  end
  ##
  # Set list color
  #
  defp add_msg(%Issue{t: @set_list_color} = issue) do
    case issue.keys["color"] do
      true  -> %Issue{issue | msg: gettext("set the color of list '%{list}'", map_to_keywords(issue.keys))}
      false -> %Issue{issue | msg: gettext("removed the color from list '%{list}'", map_to_keywords(issue.keys))}
    end
  end
  ##
  # Move cards to end of list
  #
  defp add_msg(%Issue{t: @move_cards_of_list} = issue) do

    cards = case issue.keys["count"] do
      0 -> gettext("0 cards:lowercase")
      1 -> gettext("one card:lowercase")
      n -> gettext("%{n} cards:lowercase", n: n)
    end

    keys = Map.put(issue.keys, "cards", cards)
    %Issue{issue | msg: gettext("moved %{cards} from '%{from}' to '%{to}'", map_to_keywords(keys))}
  end
  ##
  # Sort cards
  #
  defp add_msg(%Issue{t: @sort_cards} = issue) do
    %Issue{issue | msg: gettext("sorted the cards of list '%{list}'", map_to_keywords(issue.keys))}
  end
  ##
  # Archive a list
  #
  defp add_msg(%Issue{t: @archive_list} = issue) do
    %Issue{issue | msg: gettext("archived the list '%{list}'", map_to_keywords(issue.keys))}
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

  ##
  # unused function to get the translation directory mapped
  defp _translate() do
    gettext("default")
    gettext("red")
    gettext("green")
    gettext("blue")
    gettext("orange")
    gettext("pink")
    gettext("purple")
  end
end
