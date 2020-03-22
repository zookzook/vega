defmodule Vega.Issue.SetDescription do

  alias Vega.Issue.SetDescription

  @mod Vega.IssueConsts.encode(:set_description)

  defstruct description: "", m: @mod


  def new(description) do
    %SetDescription{description: description}
  end

  def to_struct(%{"m" => @mod, "description" => description}) do
    %SetDescription{description: description}
  end

end