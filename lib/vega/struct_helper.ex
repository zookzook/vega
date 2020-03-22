defmodule Vega.StructHelper do
  @moduledoc false

  def to_map(%{__struct__: _} = struct) do
    map = Map.from_struct(struct)
    :maps.map(&to_map/2, map) |> filter_nils()
  end
  def to_map(map), do: :maps.map(&to_map/2, map)
  def to_map(_key, value), do: ensure_nested_map(value)

  defp ensure_nested_map(list) when is_list(list), do: Enum.map(list, &ensure_nested_map/1)

  # NOTE: In pattern-matching order of function guards is important!
  @structs [Date, DateTime, NaiveDateTime, Time, BSON.ObjectId]
  defp ensure_nested_map(%{__struct__: struct} = data) when struct in @structs, do: data
  defp ensure_nested_map(%{__struct__: _} = struct) do
    map = Map.from_struct(struct)
    :maps.map(&to_map/2, map) |> filter_nils()
  end

  defp ensure_nested_map(data), do: data

  def filter_nils(map) when is_map(map) do
    Enum.reject(map, fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

end