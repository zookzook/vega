defmodule Vega.Plugs.SetLocale do
  @moduledoc false

  ## based on the code from https://github.com/smeevil/set_locale/blob/master/lib/set_locale.ex with some
  ## modifications

  @locales Gettext.known_locales(VegaWeb.Gettext)

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    conn
    |> get_locale_from_header()
    |> Gettext.put_locale()
    conn
  end

  defp get_locale_from_header(conn) do
    conn
    |> extract_accept_language()
    |> Enum.find(fn accepted_locale -> Enum.member?(@locales, accepted_locale) end)
  end

  defp extract_accept_language(conn) do
    case Plug.Conn.get_req_header(conn, "accept-language") do
      [value | _] ->
        value
        |> String.split(",")
        |> Enum.map(fn lang -> parse_language_option(lang) end)
        |> Enum.sort(fn left, right -> left.quality > right.quality end)
        |> Enum.map(fn %{tag: tag} -> tag end)
        |> Enum.reject(fn lang -> lang == nil end)
        |> ensure_language_fallbacks()

      _ -> ["en"]
    end
  end

  defp parse_language_option(string) do
    captures = Regex.named_captures(~r/^\s?(?<tag>[\w\-]+)(?:;q=(?<quality>[\d\.]+))?$/i, string)
    quality  = case Float.parse(captures["quality"] || "1.0") do
        {val, _} -> val
        _        -> 1.0
      end
    %{tag: captures["tag"], quality: quality}
  end

  defp ensure_language_fallbacks(tags) do
    Enum.flat_map(tags, fn tag ->
      [language | _] = String.split(tag, "-")
      if Enum.member?(tags, language) do
        [tag]
      else
        [tag, language]
      end
    end)
  end

end
