defmodule Vega.Validation do

  alias Vega.BoardList

  @doc """
  Validate the title of something. It must have a length greater 2
  """
  def validate_title(title, min_length \\ 2)
  def validate_title(nil, _min_length), do: false
  def validate_title(title, min_length), do: length(title) > min_length

  @doc """
  Validate the selected list in case of moving cards to another list. The target list should be different.
  """
  def validate_selected_list(%BoardList{id: id}, other_id) do
    id != other_id
  end

end