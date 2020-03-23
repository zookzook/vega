defmodule Vega.Dates do
  @moduledoc"""

  """

  @doc"""
  Convert a UTC date to the local date (usually "Europe / Berlin").
  """
  def to_local(d), do: Timex.Timezone.convert(d, Timex.Timezone.local())

end