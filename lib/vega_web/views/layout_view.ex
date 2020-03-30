defmodule VegaWeb.LayoutView do
  use VegaWeb, :view

  def body_class(nil) do
    []
  end
  def body_class(clazz) do
    [clazz]
  end

end
