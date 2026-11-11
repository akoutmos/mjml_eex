defmodule MjmlEEx.ValidatorTest do
  use ExUnit.Case, async: true

  alias MjmlEEx.TagEngine.Parser
  alias MjmlEEx.{ValidationError, Validator}

  @fixtures_dir Path.expand("../fixtures/validation", __DIR__)
  @corpus_dir Path.expand("../fixtures/corpus", __DIR__)

  @mjml_results @fixtures_dir
                |> Path.join("mjml_validator.json")
                |> File.read!()
                |> JSON.decode!()

  # The errors each fixture should produce, as {rule, line, column, tag, attribute}
  @expected %{
    "syntax_unclosed_tag" => [{:syntax, 4, 3, nil, nil}],
    "syntax_unclosed_quote" => [{:syntax, 10, 1, nil, nil}],
    "syntax_stray_close_tag" => [{:syntax, 3, 1, nil, nil}],
    "root_missing" => [{:root, 1, 1, "mj-body", nil}],
    "root_two_roots" => [{:root, 4, 1, "mjml", nil}],
    "root_two_bodies" => [{:root, 3, 3, "mj-body", nil}],
    "root_nested_mjml" => [{:root, 3, 5, "mjml", nil}],
    "root_text_outside" => [{:unexpected_text, 1, 1, nil, nil}],
    "root_invalid_child" => [{:root, 2, 3, "mj-section", nil}],
    "unknown_tag_typo" => [{:unknown_tag, 5, 9, "mj-txt", nil}],
    "unknown_tag_html_in_column" => [{:unknown_tag, 5, 9, "p", nil}],
    "unknown_tag_html_with_mjml_child" => [{:unknown_tag, 3, 5, "div", nil}],
    "unknown_tag_in_head" => [{:unknown_tag, 3, 5, "mj-titel", nil}],
    "unknown_tag_in_attributes" => [{:unknown_tag, 4, 7, "mj-foo", nil}],
    "unknown_tag_uppercase" => [
      {:unknown_tag, 5, 9, "table", nil},
      {:unknown_tag, 5, 16, "tr", nil},
      {:unknown_tag, 5, 20, "td", nil},
      # MJML lowercases tag names, but mrml outputs <MJ-TEXT> as an HTML element
      {:unsupported_tag, 6, 9, "MJ-TEXT", nil},
      {:unknown_attribute, 6, 18, "mj-text", "colour"}
    ],
    "unsupported_tag_html_attributes" => [{:unsupported_tag, 3, 5, "mj-html-attributes", nil}],
    "invalid_child_text_in_section" => [{:invalid_child, 4, 7, "mj-text", nil}],
    "invalid_child_column_in_body" => [{:invalid_child, 3, 5, "mj-column", nil}],
    "invalid_child_section_in_column" => [{:invalid_child, 5, 9, "mj-section", nil}],
    "invalid_child_head_component_in_body" => [{:invalid_child, 3, 5, "mj-title", nil}],
    "invalid_child_body_component_in_head" => [{:invalid_child, 3, 5, "mj-section", nil}],
    "invalid_child_carousel_image_in_column" => [{:invalid_child, 5, 9, "mj-carousel-image", nil}],
    "invalid_child_accordion_title_in_accordion" => [{:invalid_child, 6, 11, "mj-accordion-title", nil}],
    "invalid_child_wrapper_in_wrapper" => [{:invalid_child, 4, 7, "mj-wrapper", nil}],
    "invalid_child_mj_all_outside_attributes" => [{:invalid_child, 3, 5, "mj-all", nil}],
    "invalid_child_in_mj_font" => [{:invalid_child, 4, 7, "mj-text", nil}],
    "ending_tag_button_in_text" => [{:ending_tag, 5, 21, "mj-button", nil}],
    "ending_tag_section_in_raw" => [{:ending_tag, 4, 12, "mj-section", nil}],
    "unexpected_text_in_column" => [{:unexpected_text, 5, 9, "mj-column", nil}],
    "unknown_attribute_typo" => [{:unknown_attribute, 5, 18, "mj-text", "colour"}],
    "unknown_attribute_multiple" => [
      {:unknown_attribute, 5, 51, "mj-image", "foo"},
      {:unknown_attribute, 5, 59, "mj-image", "bar"}
    ],
    "unknown_attribute_in_head" => [{:unknown_attribute, 3, 68, "mj-font", "weight"}],
    "unknown_attribute_raw_text_outside_mj_raw" => [{:unknown_attribute, 5, 18, "mj-text", "mjml-raw-text"}],
    "unknown_attribute_in_attributes_child" => [{:unknown_attribute, 4, 16, "mj-text", "colour"}],
    "unknown_attribute_on_mj_class" => [{:unknown_attribute, 4, 29, "mj-class", "colr"}],
    "unknown_attribute_on_root" => [{:unknown_attribute, 1, 17, "mjml", "theme"}],
    "duplicate_attribute" => [{:duplicate_attribute, 5, 30, "mj-text", "color"}],
    "missing_attribute_mj_class_name" => [{:missing_attribute, 4, 7, "mj-class", "name"}],
    "missing_attribute_mj_include_path" => [{:missing_attribute, 3, 5, "mj-include", "path"}],
    "invalid_value_unit" => [{:invalid_value, 3, 17, "mj-section", "padding"}],
    "invalid_value_unit_too_many" => [{:invalid_value, 3, 17, "mj-section", "padding"}],
    "invalid_value_enum" => [{:invalid_value, 5, 18, "mj-text", "align"}],
    "invalid_value_color" => [{:invalid_value, 5, 18, "mj-text", "color"}],
    "invalid_value_boolean" => [{:invalid_value, 5, 51, "mj-image", "fluid-on-mobile"}],
    "invalid_value_integer" => [{:invalid_value, 5, 19, "mj-table", "cellpadding"}],
    "invalid_value_in_attributes_child" => [{:invalid_value, 4, 16, "mj-text", "align"}],
    "invalid_value_mj_include_type" => [{:invalid_value, 3, 36, "mj-include", "type"}],
    # mjml_nif ignores owa, whatever its value
    "invalid_value_root_owa" => [{:unsupported_value, 1, 7, "mjml", "owa"}, {:invalid_value, 1, 7, "mjml", "owa"}],
    "unsupported_value_inline_style" => [{:unsupported_value, 3, 15, "mj-style", "inline"}],
    "unknown_class" => [{:unknown_class, 10, 18, "mj-text", "mj-class"}],
    "empty_title" => [{:empty_title, 3, 5, "mj-title", nil}],
    # Valid MJML, but mrml doesn't support MJML 5's mj-class child tags
    "valid_kitchen_sink" => [{:unsupported_tag, 9, 9, "mj-text", nil}]
  }

  @corpus_exceptions MjmlEEx.Test.Corpus.exceptions()

  # Rules that MJML's validator has too. For these, the messages must match MJML's.
  @mjml_rules [:unknown_tag, :unknown_attribute, :invalid_value, :invalid_child]

  # Tags that MJML's validator doesn't check: it skips the root, drops mj-include, and
  # treats these as component-less tags
  @tags_mjml_skips ["mjml", "mj-include", "mj-all", "mj-class", "mj-selector", "mj-html-attribute"]

  defp validate_fixture(name) do
    case @fixtures_dir |> Path.join("#{name}.mjml") |> File.read!() |> MjmlEEx.validate() do
      :ok -> []
      {:error, errors} -> errors
    end
  end

  test "there is a fixture for every expectation and an expectation for every fixture" do
    fixtures = @fixtures_dir |> Path.join("*.mjml") |> Path.wildcard() |> Enum.map(&Path.basename(&1, ".mjml"))
    assert Enum.sort(fixtures) == Enum.sort(Map.keys(@expected))
    assert map_size(@mjml_results["fixtures"]) == length(fixtures)
  end

  test "every rule has a fixture" do
    rules = for {_name, errors} <- @expected, {rule, _, _, _, _} <- errors, uniq: true, do: rule

    assert Enum.sort(rules) ==
             Enum.sort(
               ~w(syntax root unknown_tag unsupported_tag invalid_child ending_tag unexpected_text unknown_attribute
                  duplicate_attribute missing_attribute invalid_value unsupported_value unknown_class empty_title)a
             )
  end

  for {name, expected} <- @expected do
    test "#{name} produces the expected errors" do
      errors = validate_fixture(unquote(name))

      assert Enum.map(errors, &{&1.rule, &1.line, &1.column, &1.tag, &1.attribute}) == unquote(Macro.escape(expected))
      assert Enum.all?(errors, &(&1.severity == :error))
    end

    test "#{name} agrees with MJML's validator" do
      mjml_errors =
        @mjml_results["fixtures"]
        |> Map.fetch!("#{unquote(name)}.mjml")
        |> Enum.map(&{&1["line"], &1["tag"], &1["message"]})
        |> Enum.flat_map(&without_raw_text_attribute/1)

      assert mjml_projection(validate_fixture(unquote(name))) == Enum.sort(mjml_errors)
    end
  end

  # The mjml_eex-only raw text attribute is stripped before mjml_nif sees it, so drop it
  # from MJML's unknown attribute errors on mj-raw
  defp without_raw_text_attribute({line, "mj-raw", "Attribute" <> _ = message}) do
    names =
      message
      |> String.replace(~r/^Attributes? | (is|are) illegal$/, "")
      |> String.split(", ")
      |> Kernel.--(["mjml-raw-text"])

    case names do
      [] -> []
      [name] -> [{line, "mj-raw", "Attribute #{name} is illegal"}]
      names -> [{line, "mj-raw", "Attributes #{Enum.join(names, ", ")} are illegal"}]
    end
  end

  defp without_raw_text_attribute(error), do: [error]

  # Our errors for the rules MJML shares, in MJML's format. MJML reports all of an
  # element's unknown attributes in one error. (The fixtures keep each element on one
  # line, so an attribute's line is its element's line.)
  defp mjml_projection(errors) do
    {unknown_attributes, others} =
      errors
      |> Enum.filter(&(&1.rule in @mjml_rules and &1.tag not in @tags_mjml_skips))
      |> Enum.reject(&(&1.rule == :invalid_child and not String.starts_with?(&1.message, "#{&1.tag} cannot be used")))
      |> Enum.split_with(&(&1.rule == :unknown_attribute))

    grouped =
      unknown_attributes
      |> Enum.group_by(&{&1.line, &1.tag})
      |> Enum.map(fn
        {{line, tag}, [error]} -> {line, tag, error.message}
        {{line, tag}, group} -> {line, tag, "Attributes #{Enum.map_join(group, ", ", & &1.attribute)} are illegal"}
      end)

    Enum.sort(grouped ++ Enum.map(others, &{&1.line, &1.tag, &1.message}))
  end

  describe "the corpus" do
    for fixture <- Path.wildcard(Path.join(@corpus_dir, "{compare,template}/*.mjml")) do
      relative = Path.relative_to(fixture, @corpus_dir)

      test "#{relative} validates" do
        errors =
          case unquote(fixture) |> File.read!() |> MjmlEEx.validate() do
            :ok -> []
            {:error, errors} -> errors
          end

        assert Enum.map(errors, &{&1.rule, &1.tag, &1.attribute}) == Map.get(@corpus_exceptions, unquote(relative), [])
      end

      test "#{relative} validates the same way as a template" do
        nodes = unquote(fixture) |> File.read!() |> Parser.parse!(interpolation: true)
        errors = Validator.validate(nodes)

        assert Enum.map(errors, &{&1.rule, &1.tag, &1.attribute}) == Map.get(@corpus_exceptions, unquote(relative), [])
      end
    end
  end

  describe "what mjml_nif can't compile" do
    # MJML accepts all of these, but mrml (and so mjml_nif) fails to parse them. Each case
    # checks that it still does, so a check can be removed when mrml supports it.
    @in_column "<mjml><mj-body><mj-section><mj-column>~s</mj-column></mj-section></mj-body></mjml>"
    @in_head "<mjml><mj-head>~s</mj-head><mj-body></mj-body></mjml>"
    @accordion "<mj-accordion><mj-accordion-element>~s</mj-accordion-element></mj-accordion>"

    @unsupported [
      {@in_column, "<mj-social><mj-raw><p>x</p></mj-raw></mj-social>", :unsupported_tag,
       "mj-raw inside mj-social is not supported by mrml, the MJML compiler used by mjml_nif"},
      {@in_column, "<mj-navbar><mj-raw><p>x</p></mj-raw></mj-navbar>", :unsupported_tag,
       "mj-raw inside mj-navbar is not supported by mrml, the MJML compiler used by mjml_nif"},
      {@in_column, "<mj-accordion><mj-raw><p>x</p></mj-raw></mj-accordion>", :unsupported_tag,
       "mj-raw inside mj-accordion is not supported by mrml, the MJML compiler used by mjml_nif"},
      {@in_column, String.replace(@accordion, "~s", "<mj-raw><p>x</p></mj-raw>"), :unsupported_tag,
       "mj-raw inside mj-accordion-element is not supported by mrml, the MJML compiler used by mjml_nif"},
      {"~s", "<mjml><mj-raw><p>x</p></mj-raw><mj-body></mj-body></mjml>", :unsupported_tag,
       "mj-raw inside mjml is not supported by mrml, the MJML compiler used by mjml_nif"},
      {@in_head, "<mj-title>Hello <b>you</b></mj-title>", :unsupported_tag,
       "<b> inside mj-title is not supported by mrml, the MJML compiler used by mjml_nif, which only accepts text there"},
      {@in_head, "<mj-title>Hello <!-- you --></mj-title>", :unexpected_text,
       "HTML comments inside mj-title are not supported by mrml, the MJML compiler used by mjml_nif"},
      {@in_head, "<mj-preview>Hello<br></mj-preview>", :unsupported_tag,
       "<br> inside mj-preview is not supported by mrml, the MJML compiler used by mjml_nif, which only accepts text there"},
      {@in_column, String.replace(@accordion, "~s", "<mj-accordion-title><i>a</i></mj-accordion-title>"),
       :unsupported_tag,
       "<i> inside mj-accordion-title is not supported by mrml, the MJML compiler used by mjml_nif, which only accepts text there"},
      {@in_head, ~s(<mj-breakpoint width="320px">x</mj-breakpoint>), :unexpected_text,
       "Content inside mj-breakpoint is not supported by mrml, the MJML compiler used by mjml_nif"},
      {@in_column, ~s(<mj-carousel><mj-carousel-image src="a.png">x</mj-carousel-image></mj-carousel>),
       :unexpected_text,
       "Content inside mj-carousel-image is not supported by mrml, the MJML compiler used by mjml_nif"},
      {@in_head, "<mj-style>a < b</mj-style>", :unexpected_text,
       "< inside mj-style is not supported by mrml, the MJML compiler used by mjml_nif"},
      {@in_head, ~s(<mj-attributes>\n<!-- defaults -->\n<mj-all padding="0" /></mj-attributes>), :unexpected_text,
       "HTML comments inside mj-attributes are not supported by mrml, the MJML compiler used by mjml_nif"},
      {@in_column, ~s(<mj-carousel><!-- c --><mj-carousel-image src="a.png" /></mj-carousel>), :unexpected_text,
       "HTML comments inside mj-carousel are not supported by mrml, the MJML compiler used by mjml_nif"},
      {@in_column, ~s(<mj-image src="a.png"><!-- c --></mj-image>), :unexpected_text,
       "HTML comments inside mj-image are not supported by mrml, the MJML compiler used by mjml_nif"},
      {@in_column, "<!--[if mso]><p>Outlook</p><![endif]--><mj-text>x</mj-text>", :unexpected_text,
       "Conditional comments directly inside mj-column are not supported by mrml, the MJML compiler used by mjml_nif. Put them in an mj-raw"},
      {@in_column, "<mj-text>a <!-- b -- c --></mj-text>", :unexpected_text,
       "HTML comments that contain -- are not supported by mrml, the MJML compiler used by mjml_nif"},
      {@in_head, ~s(<mj-attributes><mj-class name="a" color="red"><mj-text color="blue" /></mj-class></mj-attributes>),
       :unsupported_tag, "mj-text inside mj-class is not supported by mrml, the MJML compiler used by mjml_nif"},
      {@in_head, ~s(<mj-attributes><mj-text color="red">x</mj-text></mj-attributes>), :unexpected_text,
       "Content inside mj-text is not supported by mrml, the MJML compiler used by mjml_nif"}
    ]

    for {wrapper, mjml, rule, message} <- @unsupported do
      @mjml String.replace(wrapper, "~s", mjml)
      @rule rule
      @message message

      test "reports #{mjml}" do
        assert {:error, _reason} = Mjml.to_html(@mjml)
        assert {:error, [%ValidationError{rule: @rule, message: @message}]} = MjmlEEx.validate(@mjml)
      end
    end

    @supported [
      {@in_column, "<mj-raw><p>x</p></mj-raw>"},
      {@in_head, "<mj-raw><p>x</p></mj-raw>"},
      {@in_head, "<mj-title>Hello &amp; welcome</mj-title>"},
      {@in_head, "<mj-preview>Hello <!-- you --></mj-preview>"},
      {@in_head, ~s(<mj-breakpoint width="320px">\n</mj-breakpoint>)},
      {@in_head, "<mj-style>.a > .b { color: red; }</mj-style>"},
      {@in_column, String.replace(@accordion, "~s", "<mj-accordion-text><i>a</i> <!-- b --></mj-accordion-text>")},
      {@in_column, "<!-- a comment --><mj-text>x <!-- another --></mj-text>"},
      {@in_column, "<mj-raw><!--[if mso]><p>Outlook</p><![endif]--></mj-raw>"},
      {"<mjml><!-- c --><mj-head><!-- c --></mj-head><mj-body><!-- c -->~s</mj-body></mjml>",
       "<mj-section><!-- c --><mj-column><!-- c --></mj-column></mj-section>"},
      {"<mjml version=\"4.0.0\">~s</mjml>", "<mj-body />"}
    ]

    for {wrapper, mjml} <- @supported do
      @mjml String.replace(wrapper, "~s", mjml)

      test "accepts #{mjml} in #{wrapper |> String.split("~s") |> hd() |> String.replace(~r/<mjml>|<mj-body>/, "")}" do
        assert {:ok, _html} = Mjml.to_html(@mjml)
        assert :ok = MjmlEEx.validate(@mjml)
      end
    end

    # Each attribute in context, as {wrapper, element with ~a where the attribute goes, attribute}
    @ignored [
      {@in_column, ~s(<mj-image src="a.png"~a />), ~s(border-top="2px solid red")},
      {@in_column, ~s(<mj-image src="a.png"~a />), ~s(border-bottom="2px solid red")},
      {@in_column, ~s(<mj-image src="a.png" srcset="a.png 1x"~a />), ~s(sizes="100vw")},
      {@in_column, ~s(<mj-button href="/" background-color="red"~a>Go</mj-button>), ~s(title="Go")},
      {"<mjml>~s</mjml>", "<mj-body~a><mj-section /></mj-body>", ~s(id="main")},
      {"<mjml><mj-body>~s</mj-body></mjml>", ~s(<mj-hero background-color="red"~a><mj-text>x</mj-text></mj-hero>),
       ~s(border-radius="5px")},
      {"<mjml><mj-body>~s</mj-body></mjml>",
       ~s(<mj-section background-color="red"~a><mj-column><mj-text>a</mj-text></mj-column><mj-column><mj-text>b</mj-text></mj-column></mj-section>),
       ~s(gutter="20px")},
      {"<mjml><mj-body>~s</mj-body></mjml>",
       ~s(<mj-wrapper~a><mj-section><mj-column><mj-text>a</mj-text></mj-column></mj-section><mj-section><mj-column><mj-text>b</mj-text></mj-column></mj-section></mj-wrapper>),
       ~s(gap="20px")},
      {@in_column, "<mj-table~a><tr><td>a</td></tr></mj-table>", ~s(role="presentation")},
      {@in_column, ~s(<mj-social~a><mj-social-element name="facebook">f</mj-social-element></mj-social>),
       ~s(border="1px solid red")},
      {@in_column, ~s(<mj-social><mj-social-element name="facebook"~a>f</mj-social-element></mj-social>),
       ~s(icon-position="right")},
      {@in_column, String.replace(@accordion, "~s", "<mj-accordion-title~a>t</mj-accordion-title>"),
       ~s(font-weight="bold")},
      {"<mjml><mj-body>~s</mj-body></mjml>",
       ~s(<mj-hero background-url="a.png" height="300px"~a><mj-text>x</mj-text></mj-hero>), ~s(mode="fluid-height")},
      {"~s",
       "<mjml~a><mj-body><mj-section><mj-column><mj-text>a</mj-text></mj-column><mj-column><mj-text>b</mj-text></mj-column></mj-section></mj-body></mjml>",
       ~s(owa="desktop")},
      {"<mjml><mj-body>~s</mj-body></mjml>",
       "<mj-raw~a><p>x</p></mj-raw><mj-section><mj-column><mj-text>x</mj-text></mj-column></mj-section>",
       ~s(position="file-start")},
      {"<mjml><mj-body>~s</mj-body></mjml>",
       ~s(<mj-section background-url="https://example.com/a.png"~a><mj-column><mj-text>x</mj-text></mj-column></mj-section>),
       ~s(text-padding="37px")},
      {"<mjml><mj-body>~s</mj-body></mjml>",
       ~s(<mj-wrapper~a><mj-section><mj-column><mj-text>a</mj-text></mj-column></mj-section><mj-section><mj-column><mj-text>b</mj-text></mj-column></mj-section></mj-wrapper>),
       ~s(gutter="20px")},
      {"<mjml><mj-body>~s</mj-body></mjml>",
       ~s(<mj-wrapper background-url="https://example.com/a.png" full-width="full-width"~a><mj-section><mj-column><mj-text>x</mj-text></mj-column></mj-section></mj-wrapper>),
       ~s(text-padding="37px")},
      {@in_column, ~s(<mj-social~a><mj-social-element name="github" href="/">g</mj-social-element></mj-social>),
       ~s(table-layout="fixed")},
      {@in_column, "<mj-spacer~a />", ~s(border="2px solid red")},
      {@in_column, "<mj-spacer~a />", ~s(border-top="2px solid red")},
      {@in_column, ~s(<mj-table font-size="20px"~a><tr><td>a</td></tr></mj-table>), ~s(font-weight="700")},
      {@in_column, "<mj-text~a>x</mj-text>", ~s(background-color="red")}
    ]

    for {wrapper, element, attribute} <- @ignored do
      @without String.replace(wrapper, "~s", String.replace(element, "~a", ""))
      @with String.replace(wrapper, "~s", String.replace(element, "~a", " " <> attribute))

      test "reports #{attribute} in #{element}, which mjml_nif ignores" do
        assert Mjml.to_html(@with) == Mjml.to_html(@without)
        assert {:error, [%ValidationError{rule: :unsupported_value}]} = MjmlEEx.validate(@with)
      end
    end

    test "reports full-width=\"false\", which mjml_nif treats as full width" do
      section = "<mjml><mj-body><mj-section~s><mj-column><mj-text>a</mj-text></mj-column></mj-section></mj-body></mjml>"
      false_width = String.replace(section, "~s", ~s( full-width="false"))

      assert Mjml.to_html(false_width) == Mjml.to_html(String.replace(section, "~s", ~s( full-width="full-width")))

      assert {:error, [%ValidationError{rule: :unsupported_value, attribute: "full-width"}]} =
               MjmlEEx.validate(false_width)
    end

    test "reports MJML tags that aren't lowercase, which mjml_nif outputs as HTML elements" do
      mjml = String.replace(@in_column, "~s", "<MJ-TEXT>x</MJ-TEXT>")
      assert {:ok, html} = Mjml.to_html(mjml)
      assert html =~ "<MJ-TEXT>x</MJ-TEXT>"

      assert {:error, [%ValidationError{rule: :unsupported_tag, hint: ~s(did you mean "mj-text"?)}]} =
               MjmlEEx.validate(mjml)
    end

    test "content that comes from expressions is only checked where none is allowed" do
      assert [] = validate_template(~s(<mj-preview>{@preview}</mj-preview>), parent: "mj-head")
      assert [] = validate_template(~s(<mj-title>{@subject}</mj-title>), parent: "mj-head")

      assert [%ValidationError{rule: :unexpected_text, line: 1, column: 32}] =
               validate_template(~s(<mj-carousel-image src="a.png">{@x}</mj-carousel-image>), parent: "mj-carousel")
    end
  end

  describe "MjmlEEx.validate/2" do
    test "validates the content of an ending tag :parent as HTML" do
      assert :ok = MjmlEEx.validate("<p>Hi <b>there</b></p>", parent: "mj-text")

      assert {:error, [%ValidationError{rule: :ending_tag, tag: "mj-section"}]} =
               MjmlEEx.validate("<mj-section />", parent: "mj-text")
    end

    test "rejects unknown parents" do
      assert_raise ArgumentError, ~r/unknown :parent "mj-colum"/, fn ->
        MjmlEEx.validate("<mj-text>Hi</mj-text>", parent: "mj-colum")
      end
    end

    test "doesn't report missing attributes a spread may provide" do
      assert [] = validate_template(~s(<mj-class {@brand} />), parent: "mj-attributes")
    end

    test "suggests the attributes and tags people often mean" do
      assert {:error, [%{hint: ~s(did you mean "css-class"?)}]} =
               MjmlEEx.validate(~s(<mj-text class="a">Hi</mj-text>), parent: "mj-column")

      assert {:error, [%{hint: ~s(did you mean "background-color"?)}]} =
               MjmlEEx.validate(~s(<mj-text bgcolor="red">Hi</mj-text>), parent: "mj-column")

      assert {:error, [%{hint: ~s(did you mean "mj-divider"?)}]} = MjmlEEx.validate("<mj-hr />", parent: "mj-column")
    end

    test "validates fragments as the children of :parent" do
      assert :ok = MjmlEEx.validate(~s(<mj-text>Hi</mj-text><mj-button href="/">Go</mj-button>), parent: "mj-column")

      assert {:error, [%ValidationError{rule: :invalid_child, tag: "mj-text"}]} =
               MjmlEEx.validate(~s(<mj-text>Hi</mj-text>), parent: "mj-section")
    end

    test "includes the file in error messages" do
      assert {:error, [error]} =
               MjmlEEx.validate(~s(<mj-text colour="red">Hi</mj-text>), parent: "mj-column", file: "a.mjml")

      assert Exception.message(error) == ~s[a.mjml:1:10: Attribute colour is illegal (did you mean "color"?)]
    end

    test "treats braces as text in plain MJML" do
      mjml = ~s(<mj-text>{"a": 1} {@not_an_assign}</mj-text>)
      assert :ok = MjmlEEx.validate(mjml, parent: "mj-column")
    end

    test "returns syntax errors instead of raising" do
      assert {:error, [%ValidationError{rule: :syntax, line: 1, message: "expected closing `\"` for attribute value"}]} =
               MjmlEEx.validate(~s(<mj-text color="red>Hi</mj-text>), parent: "mj-column")
    end

    test "allows mjml-no-curly-interpolation on every element" do
      mjml = """
      <mjml mjml-no-curly-interpolation>
        <mj-head>
          <mj-attributes><mj-class name="a" color="red" mjml-no-curly-interpolation /></mj-attributes>
        </mj-head>
        <mj-body><mj-include path="footer.mjml" mjml-no-curly-interpolation /></mj-body>
      </mjml>
      """

      assert :ok = MjmlEEx.validate(mjml)
    end

    test "accepts close tags with whitespace and the HTML void tags" do
      mjml = ~s(<mj-text>a<wbr>b<br>c</mj-text ><mj-image src="a.png"></mj-image >)
      assert :ok = MjmlEEx.validate(mjml, parent: "mj-column")
    end

    test "skips the class check for documents with mj-include" do
      mjml = """
      <mjml>
        <mj-head><mj-include path="attributes.mjml" /></mj-head>
        <mj-body><mj-section><mj-column><mj-text mj-class="blue">Hi</mj-text></mj-column></mj-section></mj-body>
      </mjml>
      """

      assert :ok = MjmlEEx.validate(mjml)
    end
  end

  describe "templates with expressions" do
    defp validate_template(template, opts) do
      template
      |> Parser.parse!(interpolation: true)
      |> Validator.validate(opts)
    end

    test "doesn't type check expression values, but checks attribute names" do
      template = ~s(<mj-text color={@color} colour={@color} :if={@show}>Hi {@name}</mj-text>)

      assert [%ValidationError{rule: :unknown_attribute, attribute: "colour"}] =
               validate_template(template, parent: "mj-column")
    end

    test "validates the children of EEx blocks as children of the enclosing element" do
      template = """
      <mj-section>
        <%= if @show do %>
          <mj-text>Hi</mj-text>
        <% else %>
          <mj-column><mj-text>Hi</mj-text></mj-column>
        <% end %>
      </mj-section>
      """

      assert [%ValidationError{rule: :invalid_child, tag: "mj-text", line: 3}] =
               validate_template(template, parent: "mj-body")
    end

    test "validates the content of components but not the components themselves" do
      template = ~s(<.footer company={@company}><mj-txt>Hi</mj-txt></.footer>)

      assert [%ValidationError{rule: :unknown_tag, tag: "mj-txt"}] = validate_template(template, parent: "mj-column")
    end

    test "allows expressions directly inside containers" do
      assert [] = validate_template(~s(<mj-column>{@content}</mj-column>), parent: "mj-section")
    end
  end
end
