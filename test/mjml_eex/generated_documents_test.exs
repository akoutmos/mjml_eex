defmodule MjmlEEx.GeneratedDocumentsTest do
  use ExUnitProperties
  use ExUnit.Case, async: true

  alias MjmlEEx.Formatter
  alias MjmlEEx.Spec.{Generated, Overlay, Types}
  alias MjmlEEx.TagEngine.Compiler

  # Random valid documents built from the MJML spec: every component where MJML allows it,
  # with random attributes and values of their MJML types. Each property checks one stage
  # of the pipeline against them.
  #
  # GENERATED_RUNS=2000 mix test test/mjml_eex/generated_documents_test.exs for a longer run
  @runs String.to_integer(System.get_env("GENERATED_RUNS", "100"))

  @components Generated.components()
  @dependencies Generated.dependencies()

  # Attributes and values mjml_nif doesn't handle like MJML (the validator reports them)
  @unsupported for {tag, attribute, value, _reason} <- Overlay.attribute_value_warnings(), do: {tag, attribute, value}

  # mrml doesn't support mj-html-attributes, and mj-include needs files
  @excluded ["mj-html-attributes", "mj-include"]
  @max_depth 6

  ## Values

  # A value of an MJML type string
  defp value(type) do
    case Regex.run(~r/^(unit|unitWithNegative)\(([^)]*)\)(?:\{(\d+),(\d+)\})?$/, type) do
      [_, kind, units | counts] ->
        units = String.split(units, ",")
        {min, max} = counts(counts)

        gen all(
              count <- integer(min..max),
              values <- list_of(unit_value(kind, units), length: count)
            ) do
          Enum.join(values, " ")
        end

      nil ->
        other_value(type)
    end
  end

  defp counts([min, max]), do: {String.to_integer(min), String.to_integer(max)}
  defp counts(_counts), do: {1, 1}

  defp unit_value(kind, units) do
    gen all(
          number <- member_of([0, 1, 10, 25, 100, 600]),
          negative? <- if(kind == "unitWithNegative", do: boolean(), else: constant(false)),
          unit <- member_of(units)
        ) do
      cond do
        unit == "auto" -> "auto"
        negative? and number != 0 -> "-#{number}#{unit}"
        true -> "#{number}#{unit}"
      end
    end
  end

  defp other_value("color"), do: member_of(~w[red #fff #F45E43 rgb(1,2,3) rgba(1,2,3,0.5) transparent])
  defp other_value("boolean"), do: member_of(~w(true false))
  defp other_value("integer"), do: map(integer(0..20), &Integer.to_string/1)

  defp other_value("string"),
    do: member_of(["a", "Hello there", "2px solid #000", "https://example.com/a.png?x=1&y=2", "Ünïcødé ✓"])

  defp other_value("enum(" <> rest), do: rest |> String.trim_trailing(")") |> String.split(",") |> member_of()

  # Up to `max` different items of a list, in its order
  defp some_of(list, max) do
    gen all(mask <- list_of(frequency([{1, constant(true)}, {2, constant(false)}]), length: length(list))) do
      list |> Enum.zip(mask) |> Enum.filter(&elem(&1, 1)) |> Enum.map(&elem(&1, 0)) |> Enum.take(max)
    end
  end

  ## Elements

  # {attributes, children} for a tag, where children are elements, text or nil (self-closing)
  defp element(tag, depth) do
    gen all(
          attributes <- attributes(tag),
          children <- children(tag, depth)
        ) do
      {tag, attributes, children}
    end
  end

  # Up to three of the tag's attributes, with valid values. mj-class and css-class are left
  # out, since mj-class names must be defined in mj-attributes.
  defp attributes(tag) do
    allowed =
      @components[tag].allowed_attributes
      |> Map.drop(["mj-class", "css-class"])
      |> Enum.reject(fn {name, _type} -> {tag, name, :any} in @unsupported end)
      |> Enum.sort()

    if allowed == [] do
      constant([])
    else
      gen all(
            picked <- some_of(allowed, 3),
            values <-
              fixed_list(
                Enum.map(picked, fn {name, type} -> filter(value(type), &({tag, name, &1} not in @unsupported)) end)
              )
          ) do
        picked |> Enum.zip(values) |> Enum.map(fn {{name, _type}, value} -> {name, value} end)
      end
    end
  end

  defp children("mj-attributes", _depth) do
    # Default attributes for a few components, and a class
    gen all(
          tags <- some_of(~w(mj-text mj-button mj-section mj-image), 3),
          defaults <- fixed_list(Enum.map(tags, &attributes/1))
        ) do
      Enum.zip_with(tags, defaults, fn tag, attributes -> {tag, attributes, nil} end) ++
        [{"mj-all", [{"font-family", "Arial"}], nil}, {"mj-class", [{"name", "brand"}, {"color", "red"}], nil}]
    end
  end

  defp children(tag, depth) do
    cond do
      @components[tag].ending_tag -> content(tag)
      @dependencies[tag] in [nil, []] -> constant(nil)
      depth >= @max_depth -> constant([])
      true -> container_children(tag, depth)
    end
  end

  # mjml_nif doesn't accept mj-raw in these, though MJML does (the validator reports it)
  @no_raw ~w(mj-accordion mj-accordion-element mj-navbar mj-social)

  defp container_children(tag, depth) do
    allowed = @dependencies[tag] -- @excluded
    allowed = if tag in @no_raw, do: allowed -- ["mj-raw"], else: allowed

    gen all(tags <- list_of(member_of(allowed), max_length: max_children(tag, depth))) do
      tags
    end
    |> bind(fn tags -> fixed_list(Enum.map(tags, &element(&1, depth + 1))) end)
  end

  defp max_children("mj-body", _depth), do: 3
  defp max_children(_tag, depth) when depth >= 4, do: 2
  defp max_children(_tag, _depth), do: 3

  defp content("mj-style"), do: constant(".brand { color: #F45E43; }")
  defp content("mj-breakpoint"), do: constant(nil)
  defp content("mj-carousel-image"), do: constant(nil)
  # mjml_nif only accepts text in these (the validator reports HTML in them)
  defp content(tag) when tag in ~w(mj-title mj-preview mj-accordion-title),
    do: member_of(["Welcome", "A &amp; B", "Ünïcødé ✓"])

  defp content("mj-table"), do: constant("<tr><td>a</td><td>b</td></tr>")
  # mjml_nif parses the HTML in conditional comments, so tags they open must be closed
  defp content("mj-raw"), do: member_of(["<p>raw</p>", "<!--[if mso]><table><tr><td>x</td></tr></table><![endif]-->"])

  defp content(_tag) do
    member_of(["Hello", "Hello <b>world</b>", "a &amp; b", ~s(<a href="https://example.com">link</a>), "1<br />2"])
  end

  defp head do
    allowed = @dependencies["mj-head"] -- @excluded

    allowed
    |> some_of(4)
    |> bind(fn tags -> fixed_list(Enum.map(tags, &head_element/1)) end)
  end

  # mj-font needs a name and a URL, and mj-breakpoint a width, to mean anything
  defp head_element("mj-font"),
    do: constant({"mj-font", [{"name", "Raleway"}, {"href", "https://fonts.googleapis.com/css?family=Raleway"}], nil})

  defp head_element("mj-breakpoint"), do: map(value("unit(px)"), &{"mj-breakpoint", [{"width", &1}], nil})
  defp head_element(tag), do: element(tag, 1)

  defp document do
    gen all(
          head <- one_of([constant(nil), head()]),
          body <- element("mj-body", 1)
        ) do
      children = if head, do: [{"mj-head", [], head}, body], else: [body]
      {"mjml", [], children}
    end
  end

  ## Rendering documents

  # The document as MJML. With `holes`, the values at the given positions are written as
  # {@name} expressions instead, and their values are returned as assigns.
  defp to_mjml(element, holes \\ %{}) do
    {iodata, {assigns, _index}} = to_mjml(element, 0, holes, {%{}, 0})
    {IO.iodata_to_binary(iodata), assigns}
  end

  defp to_mjml({tag, attributes, children}, indent, holes, acc) do
    pad = String.duplicate("  ", indent)

    {attributes, acc} =
      Enum.map_reduce(attributes, acc, fn {name, value}, acc ->
        case hole(holes, acc, value) do
          {nil, acc} -> {[" ", name, "=\"", value, "\""], acc}
          {assign, acc} -> {[" ", name, "={@", assign, "}"], acc}
        end
      end)

    case children do
      nil ->
        {[pad, "<", tag, attributes, " />"], acc}

      text when is_binary(text) ->
        # {...} isn't interpolated in mj-style, so its content can't be an assign
        holes = if tag == "mj-style", do: %{}, else: holes

        {text, acc} =
          case hole(holes, acc, text) do
            {nil, acc} -> {text, acc}
            {assign, acc} -> {["{@", assign, "}"], acc}
          end

        {[pad, "<", tag, attributes, ">", text, "</", tag, ">"], acc}

      children ->
        {children, acc} = Enum.map_reduce(children, acc, &to_mjml(&1, indent + 1, holes, &2))
        {[pad, "<", tag, attributes, ">", Enum.map(children, &["\n", &1]), "\n", pad, "</", tag, ">"], acc}
    end
  end

  # Every value gets an index; those in `holes` become assigns
  defp hole(holes, {assigns, index}, value) do
    case holes do
      %{^index => replacement} ->
        name = "v#{index}"
        {name, {Map.put(assigns, String.to_atom(name), replacement.(value)), index + 1}}

      _ ->
        {nil, {assigns, index + 1}}
    end
  end

  # Positions to turn into assigns, each with a function of the original value giving the
  # assign's value
  defp holes do
    adversarial = member_of([:same, ~s[<script>alert("x")</script>], "Tom & Jerry's <b>", "a\nb", "{not code}", ""])

    gen all(picks <- list_of(tuple({integer(0..60), adversarial}), max_length: 6)) do
      Map.new(picks, fn
        {index, :same} -> {index, & &1}
        {index, value} -> {index, fn _original -> value end}
      end)
    end
  end

  defp compile(source) do
    Compiler.compile(source, file: "generated.meex")
  end

  defp render(source, assigns) do
    {rendered, _binding} = source |> compile() |> Code.eval_quoted(assigns: assigns)
    MjmlEEx.to_mjml(rendered)
  end

  # The MJML a template with assigns should render: the values written in, HTML-escaped
  # (escape/3 below)
  defp expected_mjml(document, assigns) do
    replacements =
      Map.new(assigns, fn {name, value} ->
        index = name |> Atom.to_string() |> String.trim_leading("v") |> String.to_integer()
        {index, fn _original -> value end}
      end)

    {iodata, _index} = to_literal(document, 0, replacements, 0)
    IO.iodata_to_binary(iodata)
  end

  # Like to_mjml/2, but writes the replacement values in literally
  defp to_literal({tag, attributes, children}, indent, replacements, index) do
    pad = String.duplicate("  ", indent)

    {attributes, index} =
      Enum.map_reduce(attributes, index, fn {name, value}, index ->
        {[" ", name, "=\"", replace(replacements, index, value, {tag, name}), "\""], index + 1}
      end)

    case children do
      nil ->
        {[pad, "<", tag, attributes, " />"], index}

      text when is_binary(text) ->
        {[pad, "<", tag, attributes, ">", replace(replacements, index, text, tag), "</", tag, ">"], index + 1}

      children ->
        {children, index} = Enum.map_reduce(children, index, &to_literal(&1, indent + 1, replacements, &2))
        {[pad, "<", tag, attributes, ">", Enum.map(children, &["\n", &1]), "\n", pad, "</", tag, ">"], index}
    end
  end

  defp replace(replacements, index, value, context) do
    case replacements do
      %{^index => replacement} -> escape(replacement.(value), context)
      _ -> value
    end
  end

  # mj-font's href goes into a CSS @import, where entities aren't decoded, so the characters
  # that could break out of it are percent-encoded instead
  defp escape(value, {"mj-font", "href"}),
    do: URI.encode(value, &(&1 > ?\s and &1 != 127 and &1 not in ~c[<>"'()\\{}]))

  # A background-url goes into an inline style's url('...'), so the same characters are
  # percent-encoded, and then it's HTML-escaped like other values
  defp escape(value, {tag, "background-url"}) when tag in ~w(mj-section mj-wrapper mj-hero),
    do: value |> URI.encode(&(&1 > ?\s and &1 != 127 and &1 not in ~c[<>"'()\\{}])) |> escape(nil)

  defp escape(value, _context), do: value |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  ## Properties

  property "the generator only produces values MJML accepts for their types" do
    check all(type <- member_of(Generated.type_strings()), value <- value(type), max_runs: @runs * 5) do
      assert Types.valid?(type, value), "#{inspect(value)} is not a valid #{type}"
    end
  end

  property "valid documents pass validation" do
    check all(document <- document(), max_runs: @runs) do
      {mjml, _assigns} = to_mjml(document)
      assert MjmlEEx.validate(mjml) == :ok, mjml
    end
  end

  property "documents that pass validation compile with mjml_nif" do
    check all(document <- document(), max_runs: @runs) do
      {mjml, _assigns} = to_mjml(document)
      assert {:ok, _html} = Mjml.to_html(mjml), mjml
    end
  end

  property "templates render the MJML and HTML of the same document with the values written in" do
    check all(document <- document(), holes <- holes(), max_runs: @runs) do
      {template, assigns} = to_mjml(document, holes)
      expected = expected_mjml(document, assigns)
      rendered = render(template, assigns)

      # Like HEEx, the engine writes self-closing void HTML tags as <br>; the HTML is the same
      normalized = Regex.replace(~r{<(br|img|hr)([^>]*?)\s*/>}, expected, "<\\1\\2>")

      assert rendered == normalized, template

      assert Mjml.to_html(rendered) == Mjml.to_html(expected)
    end
  end

  property "formatting templates is idempotent and doesn't change their HTML" do
    check all(document <- document(), holes <- holes(), max_runs: @runs) do
      {template, assigns} = to_mjml(document, holes)
      formatted = Formatter.format(template, extension: ".meex")

      assert Formatter.format(formatted, extension: ".meex") == formatted

      assert Mjml.to_html(render(formatted, assigns)) == Mjml.to_html(render(template, assigns)), template
    end
  end
end
