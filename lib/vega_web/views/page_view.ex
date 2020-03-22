defmodule VegaWeb.PageView do
  use VegaWeb, :view

  def make_id(prefix,id) do
    ["#", prefix, BSON.ObjectId.encode!(id)]
  end

  def make_list_id(id) do
    ["#list-", BSON.ObjectId.encode!(id)]
  end

  def make_text_id(id) do
    ["#text-", BSON.ObjectId.encode!(id)]
  end
end
