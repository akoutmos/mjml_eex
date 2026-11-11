defmodule MjmlEEx.TagEngine.Runtime do
  @moduledoc false

  require Logger

  alias MjmlEEx.Component
  alias MjmlEEx.Rendered
  alias MjmlEEx.TagEngine.Tags
  alias MjmlEEx.ValidationError
  alias MjmlEEx.Validator
  alias Phoenix.HTML.Safe

  # Where an attribute is, and the template's levels for the rules runtime validation checks
  @type levels :: %{atom() => :error | :warn | :skip}

  # Where an attribute is, the template's levels for the rules runtime validation checks, and
  # whether the template is one of MJML EEx's own (see report_at/1)
  @type location :: {String.t(), pos_integer(), pos_integer(), levels(), boolean()}

  # Attribute rendering for compiled templates.
  #
  # HTML tags follow HEEx (via Phoenix.HTML.attributes_escape/1): `nil` and `false`
  # omit the attribute, `true` renders it without a value, and lists are joined for
  # `class`.
  #
  # MJML tags (mjml and mj-*) differ in one way: MJML attribute values are strings, so
  # `true` renders as `attr="true"` (for example `fluid-on-mobile={@fluid}`). Lists are
  # joined with spaces, ignoring `nil` and `false`, which suits `mj-class` and `css-class`.

  @doc false
  @spec attribute(String.t(), String.t(), term(), location()) :: Phoenix.HTML.safe()
  def attribute(tag, name, value, location), do: attributes(tag, [{name, value}], location)

  @doc false
  @spec attributes(String.t(), Enumerable.t(), location()) :: Phoenix.HTML.safe()
  def attributes(tag, attributes, location) do
    if Tags.mjml?(tag) do
      attributes =
        attributes
        |> stringify_keys()
        |> Enum.map(fn {name, value} -> {name, mjml_value(value)} end)

      maybe_validate(tag, attributes, location)
      attributes |> Enum.map(&css_url(tag, &1)) |> Phoenix.HTML.attributes_escape()
    else
      Phoenix.HTML.attributes_escape(attributes)
    end
  end

  # URLs that mrml copies into CSS. In them, the characters that could end the url(...), the
  # attribute, the <style> element or the conditional comment around them are percent-encoded,
  # which keeps the URL working.
  #
  # mj-font's href goes as is into a <link href="..."> and into a CSS `@import url(...)` in a
  # <style> element, where entities aren't decoded, so it can't be HTML-escaped (a & escaped as
  # &amp; would break the URL).
  defp css_url("mj-font", {"href", value}) when is_binary(value),
    do: {"href", {:safe, URI.encode(value, &url_char?/1)}}

  # A background-url goes into an inline style's url('...'), where the browser decodes
  # entities first, so an HTML-escaped ' would still end the url('...'). It's HTML-escaped too.
  defp css_url(tag, {"background-url", value}) when tag in ~w(mj-section mj-wrapper mj-hero) and is_binary(value),
    do: {"background-url", URI.encode(value, &url_char?/1)}

  defp css_url(_tag, attribute), do: attribute

  defp url_char?(char), do: char > ?\s and char != 127 and char not in ~c[<>"'()\\{}]

  @doc false
  # Interpolated values that are lists may contain rendered templates, as from
  # `{for item <- @items, do: row(item)}`; Phoenix.HTML only accepts safe tuples in lists
  @spec to_safe(term()) :: term()
  def to_safe(list) when is_list(list), do: {:safe, list |> unwrap_rendered() |> Safe.to_iodata()}
  def to_safe(value), do: value

  defp unwrap_rendered([head | tail]), do: [unwrap_rendered(head) | unwrap_rendered(tail)]
  defp unwrap_rendered(%Rendered{mjml: mjml}), do: {:safe, mjml}
  defp unwrap_rendered(other), do: other

  @doc false
  # The rules that runtime validation checks. Templates pass their levels for them.
  @spec validated_rules() :: [atom()]
  def validated_rules, do: [:unknown_attribute, :invalid_value, :unsupported_value]

  # With `config :mjml_eex, runtime_validation: :raise` or `:warn`, the values of MJML
  # attributes that come from expressions are checked as they're rendered. A problem is
  # reported at the lower of that setting and the template's level for its rule, so a rule the
  # template sets to :warn only warns, and one set to :skip isn't checked.
  defp maybe_validate(tag, attributes, location) do
    case runtime_validation() do
      :skip ->
        :ok

      mode ->
        {file, line, column, levels, suffix} = report_at(location)

        for {name, value} <- attributes, value not in [nil, false] do
          with %ValidationError{rule: rule} = error <- Validator.check_attribute(tag, name, value_to_string(value)) do
            error = %{error | file: file, line: line, column: column, message: error.message <> suffix}
            report(error, lower(mode, Map.get(levels, rule, :error)))
          end
        end

        :ok
    end
  end

  # Problems in the core components and prebuilt templates come from the values the user's
  # template passes them, so they're reported where it calls the component, at its levels
  defp report_at({file, line, column, levels, library?}) do
    case library? && Component.__caller__() do
      {file, line, column, levels, display} -> {file, line, column, levels, " (for #{display})"}
      _ -> {file, line, column, levels, ""}
    end
  end

  defp report(_error, :skip), do: :ok
  defp report(error, :warn), do: Logger.warning(Exception.message(%{error | severity: :warn}))
  defp report(error, :error), do: raise(error)

  defp lower(_mode, :skip), do: :skip
  defp lower(:warn, _level), do: :warn
  defp lower(_mode, level), do: level

  defp runtime_validation do
    case Application.get_env(:mjml_eex, :runtime_validation, false) do
      off when off in [false, nil, :skip] ->
        :skip

      :warn ->
        :warn

      on when on in [true, :raise, :error] ->
        :error

      other ->
        raise ArgumentError,
              "invalid config :mjml_eex, runtime_validation: #{inspect(other)}. Expected :raise, :warn or false"
    end
  end

  defp value_to_string({:safe, data}), do: IO.iodata_to_binary(data)
  defp value_to_string(value), do: to_string(value)

  # On MJML tags, atom keys are kept as written (Phoenix.HTML would dasherize them, as it
  # does on HTML tags)
  defp stringify_keys(attributes) do
    Enum.map(attributes, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp mjml_value(true), do: "true"

  defp mjml_value(list) when is_list(list) do
    list |> List.flatten() |> Enum.reject(&(&1 in [nil, false])) |> Enum.map_join(" ", &value_to_string/1)
  end

  defp mjml_value(value), do: value
end
