defmodule Vega.Issue.AddComment do

  alias Vega.Issue.AddComment

  @add_comment Vega.IssueConsts.encode(:add_comment)

  defstruct comment: "", m:  @add_comment

  def new(comment) do
    %AddComment{comment: comment}
  end

  def to_struct(%{"m" => @add_comment, "comment" => comment}) do
    %AddComment{comment: comment}
  end
end