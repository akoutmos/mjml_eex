# Ported from MJML's mjml-core/src/types/*.js (boolean, color, enum, integer, string,
# type, unit and helpers/colors), MJML v5.4.1 (https://github.com/mjmlio/mjml, commit 1c434fc).
# MJML is MIT licensed: Copyright (c) 2016 Mailjet SAS, https://mjml.io
defmodule MjmlEEx.Spec.Types.Checker do
  @moduledoc false

  # Builds and runs the checkers behind MjmlEEx.Spec.Types. This is a separate module
  # so that MjmlEEx.Spec.Types can build its checkers at compile time.
  #
  # Checkers hold regex sources rather than compiled regexes, because compiled regexes
  # can't be stored at compile time on Elixir 1.18 with OTP 28. Each regex is compiled
  # the first time it's used and cached in :persistent_term.

  alias MjmlEEx.Spec.Generated

  # Mirrors mjml-core/src/types/index.js. MJML picks the first family whose matcher
  # matches the type string, in this order. The matchers have the `i` flag.
  @families [
    boolean: "^boolean",
    enum: "^enum",
    color: "^color",
    unit: "^(unit|unitWithNegative)\\(.*\\)",
    string: "^string",
    integer: "^integer"
  ]

  # JavaScript's \s, which also matches Unicode spaces
  @js_whitespace "[\\t\\n\\x{0B}\\f\\r \\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{2028}\\x{2029}\\x{202F}\\x{205F}\\x{3000}\\x{FEFF}]"

  @type regex_source :: {String.t(), [atom()]}
  @type t ::
          {:matchers, [regex_source()], {:template, String.t()} | {:type_name, String.t()}}
          | :boolean

  @doc false
  @spec check(t(), String.t()) :: boolean()
  def check(:boolean, value), do: value in ["true", "false"]
  def check({:matchers, matchers, _message}, value), do: Enum.any?(matchers, &Regex.match?(regex(&1), value))

  @doc false
  @spec error_message(t(), String.t()) :: String.t()
  def error_message(checker, value), do: render_error_message(checker, value)

  # Type.getErrorMessage: the message (or the default one) with every `$value` replaced
  # by the value, using JavaScript's String#replace semantics
  defp render_error_message({:matchers, _matchers, {:template, template}}, value) do
    js_replace_all(template, "$value", value)
  end

  defp render_error_message({:matchers, _matchers, {:type_name, type_name}}, value) do
    js_replace_all("has invalid value: #{value} for type #{type_name} ", "$value", value)
  end

  defp render_error_message(:boolean, value) do
    js_replace_all("has invalid value: #{value} for type Boolean ", "$value", value)
  end

  @doc false
  @spec build(String.t()) :: t()
  def build(type_string) do
    case Enum.find(@families, fn {_family, source} -> Regex.match?(regex({source, [:caseless]}), type_string) end) do
      {family, _matcher} -> build(family, type_string)
      nil -> raise ArgumentError, "No type found for #{type_string}"
    end
  end

  defp build(:boolean, _type_string), do: :boolean

  # mjml-core/src/types/enum.js
  defp build(:enum, type_string) do
    values = parenthesized_list!(type_string)
    matchers = Enum.map(values, &compile!("^#{Regex.escape(&1)}$"))

    {:matchers, matchers,
     {:template, "has invalid value: $value for type Enum, only accepts #{Enum.join(values, ", ")}"}}
  end

  # mjml-core/src/types/color.js
  defp build(:color, _type_string) do
    digit = "[0-9]"
    space = @js_whitespace <> "?"
    named_colors = Enum.join(Generated.named_colors(), "|")

    matchers = [
      compile!(
        "rgba\\(#{digit}{1,3},#{space}#{digit}{1,3},#{space}#{digit}{1,3},#{space}#{digit}(\\.#{digit}{1,3})?\\)",
        [:caseless, :unicode]
      ),
      compile!("rgb\\(#{digit}{1,3},#{space}#{digit}{1,3},#{space}#{digit}{1,3}\\)", [:caseless, :unicode]),
      compile!("^#([0-9a-f]{3}){1,2}$", [:caseless]),
      compile!("^(#{named_colors})$")
    ]

    {:matchers, matchers, {:type_name, "Color"}}
  end

  # mjml-core/src/types/unit.js
  defp build(:unit, type_string) do
    allow_negative = if String.starts_with?(type_string, "unitWithNegative"), do: "-|", else: ""
    units = parenthesized_list!(type_string)

    args =
      case Regex.run(regex({"\\{([^}]+)\\}", []}), type_string) do
        [_, args] -> String.split(args, ",")
        nil -> ["1"]
      end

    allow_auto = if "auto" in units, do: "|auto", else: ""
    filtered_units = units |> Enum.reject(&(&1 == "auto")) |> Enum.map_join("|", &Regex.escape/1)

    matcher =
      compile!(
        "^(((#{allow_negative}[0-9]|,|\\.){1,}(#{filtered_units})|0#{allow_auto})( )?){#{Enum.join(args, ",")}}$"
      )

    message =
      "has invalid value: $value for type Unit, only accepts (#{Enum.join(units, ", ")}) units and " <>
        "#{Enum.join(args, " to ")} value(s)"

    {:matchers, [matcher], {:template, message}}
  end

  # mjml-core/src/types/string.js
  defp build(:string, _type_string), do: {:matchers, [compile!(".*")], {:type_name, "NString"}}

  # mjml-core/src/types/integer.js
  defp build(:integer, _type_string), do: {:matchers, [compile!("[0-9]+")], {:type_name, "NInteger"}}

  # The first parenthesized group, split on commas: params.match(/\(([^)]+)\)/)[1].split(',')
  defp parenthesized_list!(type_string) do
    case Regex.run(regex({"\\(([^)]+)\\)", []}), type_string) do
      [_, list] -> String.split(list, ",")
      nil -> raise ArgumentError, "Invalid MJML type #{type_string}"
    end
  end

  # In JavaScript (without the `m` flag), `$` only matches at the very end of the input
  defp compile!(source, opts \\ []), do: {source, [:dollar_endonly | opts]}

  defp regex({source, opts} = regex_source) do
    key = {__MODULE__, regex_source}

    case :persistent_term.get(key, nil) do
      nil ->
        regex = Regex.compile!(source, opts)
        :persistent_term.put(key, regex)
        regex

      regex ->
        regex
    end
  end

  # JavaScript's String#replace with a global search string. In the replacement, `$$`
  # inserts `$`, `$&` the match, `` $` `` the text before the match and `$'` the text after it.
  defp js_replace_all(string, search, replacement) do
    string
    |> :binary.matches(search)
    |> Enum.reduce({[], 0}, fn {start, length}, {acc, position} ->
      before = binary_part(string, 0, start)
      after_match = binary_part(string, start + length, byte_size(string) - start - length)
      expanded = expand_js_replacement(replacement, search, before, after_match)

      {[acc, binary_part(string, position, start - position), expanded], start + length}
    end)
    |> then(fn {acc, position} ->
      IO.iodata_to_binary([acc, binary_part(string, position, byte_size(string) - position)])
    end)
  end

  defp expand_js_replacement(replacement, match, before, after_match) do
    expand_js_replacement(replacement, match, before, after_match, [])
  end

  defp expand_js_replacement(<<"$$", rest::binary>>, match, before, after_match, acc),
    do: expand_js_replacement(rest, match, before, after_match, [acc, "$"])

  defp expand_js_replacement(<<"$&", rest::binary>>, match, before, after_match, acc),
    do: expand_js_replacement(rest, match, before, after_match, [acc, match])

  defp expand_js_replacement(<<"$`", rest::binary>>, match, before, after_match, acc),
    do: expand_js_replacement(rest, match, before, after_match, [acc, before])

  defp expand_js_replacement(<<"$'", rest::binary>>, match, before, after_match, acc),
    do: expand_js_replacement(rest, match, before, after_match, [acc, after_match])

  defp expand_js_replacement(<<char::utf8, rest::binary>>, match, before, after_match, acc),
    do: expand_js_replacement(rest, match, before, after_match, [acc, <<char::utf8>>])

  defp expand_js_replacement(<<byte, rest::binary>>, match, before, after_match, acc),
    do: expand_js_replacement(rest, match, before, after_match, [acc, byte])

  defp expand_js_replacement(<<>>, _match, _before, _after_match, acc), do: IO.iodata_to_binary(acc)
end
