defmodule MjmlEEx.FormatterTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Mix.Tasks.Format
  alias MjmlEEx.Formatter
  alias MjmlEEx.Spec.Generated
  alias MjmlEEx.TagEngine.{Serializer, Tags}

  @corpus_dir Path.expand("../fixtures/corpus", __DIR__)

  defp format(source, opts \\ []), do: Formatter.format(source, Keyword.put_new(opts, :extension, ".meex"))

  @ending_tags for {name, %{ending_tag: true}} <- Generated.components(), do: name

  # mrml drops whitespace between components when it starts with a newline, but copies any
  # other whitespace (" ", "\t", " \n ") into the HTML as-is, between table markup, where it
  # has no visible effect. The formatter puts each component on its own line, so it can't
  # keep that whitespace. To compare HTML byte for byte, the original's whitespace directly
  # inside container components (and around comments there) is normalized to "\n" first, and
  # "\r\n" line endings to "\n" (the formatter writes "\n", like the Elixir formatter).
  # Ending tag content, where whitespace can matter, is otherwise left alone.
  defp normalize_structural_whitespace(source) do
    source
    |> String.replace("\r\n", "\n")
    |> MjmlEEx.parse!()
    |> normalize_nodes()
    |> Serializer.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp normalize_nodes(nodes) do
    Enum.map(nodes, fn
      {:text, text, meta} ->
        text =
          ~r/<!--.*?-->/s
          |> Regex.split(text, include_captures: true)
          |> Enum.map_join(fn part -> if part != "" and ascii_whitespace?(part), do: "\n", else: part end)

        {:text, text, meta}

      {:block, :tag, name, attrs, children, meta, close} ->
        children = if container?(name), do: normalize_nodes(children), else: children
        {:block, :tag, name, attrs, children, meta, close}

      node ->
        node
    end)
  end

  defp ascii_whitespace?(text), do: String.split(text, [" ", "\t", "\n", "\r"], trim: true) == []

  defp container?(name), do: Tags.mjml?(name) and name not in @ending_tags and name != "mj-style"

  defp assert_same_html(source, formatted) do
    assert Mjml.to_html(formatted) == Mjml.to_html(normalize_structural_whitespace(source))
  end

  # Asserts the formatted output and that formatting it again changes nothing
  defp assert_formatted(source, expected, opts \\ []) do
    formatted = format(source, opts)
    assert formatted == expected
    assert format(formatted, opts) == expected
  end

  test "claims the ~MJML sigil and .meex files" do
    assert Formatter.features([]) == [sigils: [:MJML], extensions: [".meex"]]
  end

  describe "layout" do
    test "puts each MJML component on its own line, indented" do
      assert_formatted(
        ~s(<mjml><mj-body><mj-section><mj-column><mj-text>Hi</mj-text><mj-button href="/">Go</mj-button></mj-column></mj-section></mj-body></mjml>),
        """
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-text>Hi</mj-text>
                <mj-button href="/">Go</mj-button>
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
        """
      )
    end

    test "self-closes empty MJML components" do
      assert_formatted(
        """
        <mj-column>
          <mj-image src="a.png"></mj-image>
          <mj-divider>
          </mj-divider>
          <mj-spacer/>
          <mj-text></mj-text>
        </mj-column>
        """,
        """
        <mj-column>
          <mj-image src="a.png" />
          <mj-divider />
          <mj-spacer />
          <mj-text />
        </mj-column>
        """
      )
    end

    test "keeps the content of ending tags exactly as written" do
      source = """
      <mj-column>
        <mj-text   align="center"  >
            Hello   <b>{  @name  }</b>,<br>
          welcome!
        </mj-text>
        <mj-button href="/">  Go  </mj-button>
        <mj-raw><!--[if mso]><table><tr><td><![endif]--></mj-raw>
      </mj-column>
      """

      assert_formatted(source, """
      <mj-column>
        <mj-text align="center">
            Hello   <b>{  @name  }</b>,<br>
          welcome!
        </mj-text>
        <mj-button href="/">  Go  </mj-button>
        <mj-raw><!--[if mso]><table><tr><td><![endif]--></mj-raw>
      </mj-column>
      """)
    end

    test "keeps mj-style, raw text mj-raw and mjml-no-format content exactly as written" do
      source = """
      <mjml>
        <mj-head>
          <mj-style>
            .a   { color: red; }
                .b { color: blue; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-raw mjml-raw-text><div   class="open"></mj-raw>
          <mj-section mjml-no-format><mj-column>   <mj-text>Hi</mj-text></mj-column></mj-section>
        </mj-body>
      </mjml>
      """

      assert_formatted(source, source)
    end

    test "keeps comments and one blank line between groups" do
      assert_formatted(
        """
        <mj-column>
          <!-- Header -->
          <mj-text>A</mj-text>



          <mj-text>B</mj-text>
        </mj-column>
        """,
        """
        <mj-column>
          <!-- Header -->
          <mj-text>A</mj-text>

          <mj-text>B</mj-text>
        </mj-column>
        """
      )
    end
  end

  describe "components" do
    test "function components and slots on separate lines are indented, like MJML components" do
      assert_formatted(
        ~S"""
        <mj-body><Components.table items={@items}>
        <:column width="30%" :let={item}><mj-text>{item.name}</mj-text></:column>
        <:column :let={row}><mj-text>{row.price}</mj-text></:column>
        </Components.table><mj-section><mj-column>
        <.cta href="/go" {@attrs}>Go</.cta>
        <.box :if={@show} />
        </mj-column></mj-section></mj-body>
        """,
        ~S"""
        <mj-body>
          <Components.table items={@items}>
            <:column width="30%" :let={item}>
              <mj-text>{item.name}</mj-text>
            </:column>
            <:column :let={row}>
              <mj-text>{row.price}</mj-text>
            </:column>
          </Components.table>
          <mj-section>
            <mj-column>
              <.cta href="/go" {@attrs}>Go</.cta>
              <.box :if={@show} />
            </mj-column>
          </mj-section>
        </mj-body>
        """
      )
    end

    # A component can render into an ending tag, where whitespace next to it would show
    test "function components that touch other content stay together, as in HEEx" do
      for {source, touching} <- [
            {"<.heading>Hello <.name />!</.heading>\n", "<.name />!"},
            {"<.cta href=\"/go\"><.icon />Get started</.cta>\n", "<.icon />Get started"},
            {"<.card><:title>Hi</:title>Body</.card>\n", "</:title>Body"},
            {"<mj-column>\n  <.cta href=\"/\">Go</.cta><.box />\n</mj-column>\n", "</.cta><.box />"}
          ] do
        formatted = format(source)
        assert format(formatted) == formatted
        assert formatted =~ touching
      end
    end

    test "comments that touch other content stay inline" do
      for source <- ["<.heading>{@a}<!-- c -->{@b}</.heading>\n", "<.heading><b>Hi</b>there <!-- note --></.heading>\n"] do
        assert format(source) == source
      end
    end
  end

  describe "regressions" do
    test "<%# %> comments inside <%!-- --%> comments and EEx tags are left alone" do
      source =
        "<mj-column>\n  <%!-- disabled:\n<mj-text>a</mj-text>\n<%# note %>\n<mj-text>b</mj-text>\n--%>\n</mj-column>\n"

      formatted = format(source)

      assert formatted =~ "<%# note %>"
      refute formatted =~ "<%!-- note --%>"
      assert format(formatted) == formatted

      assert format(~s(<mj-text><%= "<%#" %> <%# old %></mj-text>\n)) ==
               ~s(<mj-text><%= "<%#" %> <%!-- old --%></mj-text>\n)
    end

    test "a leading byte order mark is removed without shifting the content kept as written" do
      assert format("\uFEFF<mj-column><mj-text>hello</mj-text></mj-column>") ==
               "<mj-column>\n  <mj-text>hello</mj-text>\n</mj-column>\n"

      assert format("\uFEFF<mj-text>hello {@x}</mj-text>\r\n") == "<mj-text>hello {@x}</mj-text>\n"
    end

    test "EEx in a comment that follows another comment is kept, since {...} isn't interpolated in comments" do
      for source <- [
            "<mj-column>\n  <!-- a -->\n  <!-- <%= @x %> -->\n</mj-column>\n",
            "<mj-column>\n  <!-- a --> <!-- <%= @x %> -->\n</mj-column>\n",
            ~s(<mj-raw><!--[if mso]><table><![endif]--><!--[if mso]><td width="<%= @w %>"><![endif]--></mj-raw>\n)
          ] do
        assert format(source) == source
      end
    end

    test "comments that cross the end of an EEx block are left as they are" do
      for source <- [
            "<mj-column>\n<%= if @a do %><!-- <% end %> -->\n</mj-column>\n",
            "<mj-column>\n<!-- <%= if @a do %> --> <% end %>\n</mj-column>\n",
            "<.box><%= if @a do %><!-- <% end %> --></.box>\n"
          ] do
        assert format(source) == source
      end
    end

    test "blank lines in EEx blocks in comments are kept as they are" do
      source = "<mj-column>\n  <!-- <%= if @a do %>\n\n<% end %> -->\n</mj-column>\n"
      assert format(source) == source
    end

    test "blank lines around comments with EEx are kept" do
      source = "<mj-column>\n  <mj-text>a</mj-text>\n\n  <!-- <%= @a %> -->\n\n  <mj-text>b</mj-text>\n</mj-column>\n"
      assert format(source) == source
    end

    test "<%# %> comments are written as <%!-- --%>, rather than dropped" do
      assert format("<mj-column>\n  <%# note %>\n  <mj-text>a</mj-text>\n</mj-column>\n") ==
               "<mj-column>\n  <%!-- note --%>\n  <mj-text>a</mj-text>\n</mj-column>\n"
    end

    test "spaces between tags in component content become a single line break" do
      formatted = format("<.card>\n  <p>First</p> <p>Second</p>\n</.card>\n")
      assert formatted == "<.card>\n  <p>First</p>\n  <p>Second</p>\n</.card>\n"
      assert format(formatted) == formatted
    end

    test "single-line sigils are left as they are when formatting would add their closing delimiter" do
      assert format("<mj-image src='a.png' />", sigil: :MJML, opening_delimiter: "\"") == "<mj-image src='a.png' />"

      assert format("<mj-image src={Enum.join @parts} />", sigil: :MJML, opening_delimiter: "(") ==
               "<mj-image src={Enum.join @parts} />"

      assert format(~s(<mj-image src="a.png"></mj-image>), sigil: :MJML, opening_delimiter: "|") ==
               ~s(<mj-image src="a.png" />)
    end

    test "syntax errors in sigils point to the line in the file" do
      error =
        assert_raise MjmlEEx.ParseError, fn ->
          format("<mj-section>\n  <mj-column>\n</mj-section>\n",
            sigil: :MJML,
            opening_delimiter: ~S("""),
            line: 10,
            file: "a.ex"
          )
        end

      assert {error.file, error.line} == {"a.ex", 13}
    end

    test "MJML components followed directly by an expression, comment or text are still formatted" do
      for suffix <- ["<%= @footer %>", "{@footer}", "<!-- c -->"] do
        source = "<mj-body><mj-section>\n<mj-column><mj-text>a</mj-text></mj-column>\n</mj-section>#{suffix}</mj-body>"
        formatted = format(source)

        assert formatted =~ "  <mj-section>\n    <mj-column>\n"
        assert format(formatted) == formatted
      end
    end

    test "<%= %> is not turned into {} where curly interpolation is off" do
      source = "<mj-section mjml-no-curly-interpolation>\n  <mj-column><%= raw(@x) %></mj-column>\n</mj-section>\n"
      assert format(source) == source
    end

    test "string expressions in attributes are not flattened, since that would change escaping" do
      source = ~s(<mj-image alt={"&amp;"} src={"a.png"} />\n)
      assert format(source) == source
    end

    test "non-ASCII spaces are kept" do
      formatted = format("<mj-column>\u00a0<mj-text>a</mj-text></mj-column>")
      assert formatted =~ "\u00a0"
      assert format(formatted) == formatted
    end
  end

  describe "a realistic email" do
    # Multi-line content of ending tags and mj-style is kept byte for byte, including its
    # indentation, so here it's already indented for its final position
    test "is formatted like this" do
      source = ~S"""
      <mjml lang="en"><mj-head><mj-title>{@subject}</mj-title><mj-preview>{@preview}</mj-preview>
      <mj-attributes><mj-all font-family="Helvetica, Arial, sans-serif"></mj-all><mj-class name="muted" color="#9B9B9B" font-size="12px"></mj-class></mj-attributes>
      <mj-style>
            .cta a { text-decoration: none; }
          </mj-style></mj-head>
      <mj-body background-color="#F2F2F2">
      <mj-hero mode="fixed-height" height="320px" background-url={@hero_url} background-color="#2a3448" padding="100px 0px">
      <mj-text align="center" font-size="32px" color="#ffffff">Welcome, {@first_name}!</mj-text>
      <mj-button href={@cta_url} css-class="cta" background-color="#F45E43">Get started</mj-button></mj-hero>
      <!-- Features -->
      <mj-section :for={feature <- @features}><mj-column><mj-image src={feature.image} width="64px"></mj-image></mj-column>
      <mj-column><mj-text>
                <h3>{feature.title}</h3>
                {feature.body}
              </mj-text></mj-column></mj-section>
      <%= if @show_social do %><mj-section><mj-column><mj-social mode="horizontal"><mj-social-element name="github" href="https://github.com">GitHub</mj-social-element></mj-social></mj-column></mj-section><% end %>
      <mj-section><mj-column><mj-text mj-class="muted" align="center">Sent by {@company}. <a href={@unsubscribe_url}>Unsubscribe</a></mj-text></mj-column></mj-section>
      </mj-body></mjml>
      """

      assert_formatted(source, ~S"""
      <mjml lang="en">
        <mj-head>
          <mj-title>{@subject}</mj-title>
          <mj-preview>{@preview}</mj-preview>
          <mj-attributes>
            <mj-all font-family="Helvetica, Arial, sans-serif" />
            <mj-class name="muted" color="#9B9B9B" font-size="12px" />
          </mj-attributes>
          <mj-style>
            .cta a { text-decoration: none; }
          </mj-style>
        </mj-head>
        <mj-body background-color="#F2F2F2">
          <mj-hero
            mode="fixed-height"
            height="320px"
            background-url={@hero_url}
            background-color="#2a3448"
            padding="100px 0px"
          >
            <mj-text align="center" font-size="32px" color="#ffffff">Welcome, {@first_name}!</mj-text>
            <mj-button href={@cta_url} css-class="cta" background-color="#F45E43">Get started</mj-button>
          </mj-hero>
          <!-- Features -->
          <mj-section :for={feature <- @features}>
            <mj-column>
              <mj-image src={feature.image} width="64px" />
            </mj-column>
            <mj-column>
              <mj-text>
                <h3>{feature.title}</h3>
                {feature.body}
              </mj-text>
            </mj-column>
          </mj-section>
          <%= if @show_social do %>
            <mj-section>
              <mj-column>
                <mj-social mode="horizontal">
                  <mj-social-element name="github" href="https://github.com">GitHub</mj-social-element>
                </mj-social>
              </mj-column>
            </mj-section>
          <% end %>
          <mj-section>
            <mj-column>
              <mj-text mj-class="muted" align="center">Sent by {@company}. <a href={@unsubscribe_url}>Unsubscribe</a></mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
      """)
    end
  end

  describe "attributes" do
    test "wrap one per line when they don't fit, without reordering" do
      assert_formatted(
        ~s(<mj-section padding="10px 0 20px 0" background-color="#FFFFFF" :for={item <- @items} css-class="a-very-long-class-name"><mj-column /></mj-section>),
        """
        <mj-section
          padding="10px 0 20px 0"
          background-color="#FFFFFF"
          :for={item <- @items}
          css-class="a-very-long-class-name"
        >
          <mj-column />
        </mj-section>
        """
      )
    end

    test "honor :line_length and :mjml_line_length" do
      source = ~s(<mj-image src="https://example.com/a.png" alt="An image" />)
      assert format(source) == source <> "\n"

      assert format(source, line_length: 40) == """
             <mj-image
               src="https://example.com/a.png"
               alt="An image"
             />
             """

      assert format(source, line_length: 40, mjml_line_length: 200) == source <> "\n"
    end

    test "attributes already on separate lines stay that way" do
      source = """
      <mj-image
        src="a.png"
        alt=""
      />
      """

      assert_formatted(source, source)
    end
  end

  describe "Elixir code" do
    test "is formatted in interpolations, attributes and EEx tags" do
      assert_formatted(
        """
        <mj-column>
          <mj-image src={  url(@image ,  :large)  } :if={@show&&@image} />
          {  render_footer( assigns )  }
          <%= for item<-@items do %>
            <mj-text>{item}</mj-text>
          <% end %>
          <%=   @extra   %>
        </mj-column>
        """,
        """
        <mj-column>
          <mj-image src={url(@image, :large)} :if={@show && @image} />
          {render_footer(assigns)}
          <%= for item<-@items do %>
            <mj-text>{item}</mj-text>
          <% end %>
          {@extra}
        </mj-column>
        """
      )
    end

    test "EEx migration can be turned off" do
      source = "<mj-column>\n  <%= @extra %>\n</mj-column>\n"
      assert format(source, migrate_eex_to_curly_interpolation: false) == source
    end
  end

  describe "sigils" do
    test "the noformat modifier skips formatting" do
      source = "<mj-column><mj-text>Hi</mj-text></mj-column>"
      assert Formatter.format(source, sigil: :MJML, modifiers: ~c"noformat") == source
    end

    test "single-character delimiters don't get a trailing newline" do
      assert Formatter.format("<mj-text>Hi</mj-text>", sigil: :MJML, opening_delimiter: "\"") == "<mj-text>Hi</mj-text>"
    end
  end

  describe "tag formatters" do
    defmodule UpcaseCSS do
      @behaviour MjmlEEx.Formatter.TagFormatter

      @impl true
      def render_tag({"mj-style", %{"inline" => "inline"}, _content}, _opts), do: :skip
      def render_tag({"mj-style", _attrs, content}, _opts), do: {:ok, content |> String.trim() |> String.upcase()}
    end

    test "format mj-style content" do
      source =
        "<mj-head>\n  <mj-style>.a { color: red; }</mj-style>\n  <mj-style inline=\"inline\">.b {}</mj-style>\n</mj-head>\n"

      assert format(source, tag_formatters: %{"mj-style": UpcaseCSS}) == """
             <mj-head>
               <mj-style>
                 .A { COLOR: RED; }
               </mj-style>
               <mj-style inline="inline">.b {}</mj-style>
             </mj-head>
             """
    end
  end

  test "mjml-no-format is not rendered" do
    {{:module, module, _, _}, _} =
      Code.eval_string("""
      defmodule MjmlEEx.FormatterTest.NoFormat do
        use MjmlEEx
        def render(assigns), do: ~MJML"<mj-text mjml-no-format>  Hi  </mj-text>"
      end
      """)

    assert module.render(%{}) |> MjmlEEx.to_mjml() == "<mj-text>  Hi  </mj-text>"
  end

  test "the whitespace normalization only touches whitespace inside containers" do
    source =
      "<mjml>\t<mj-body> <mj-section>\r\n<mj-column> <!-- a --> <mj-text> a \r\n b </mj-text></mj-column></mj-section></mj-body></mjml>"

    assert normalize_structural_whitespace(source) ==
             "<mjml>\n<mj-body>\n<mj-section>\n<mj-column>\n<!-- a -->\n<mj-text> a \n b </mj-text></mj-column></mj-section></mj-body></mjml>"
  end

  describe "mix format" do
    @tag :tmp_dir
    test "formats and checks .meex files and ~MJML sigils", %{tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, ".formatter.exs"), ~s([plugins: [MjmlEEx.Formatter], inputs: ["*.{ex,meex}"]]))

      template = Path.join(tmp_dir, "welcome.meex")
      File.write!(template, "<mj-column><mj-text>Hi</mj-text></mj-column>")

      module = Path.join(tmp_dir, "welcome.ex")

      File.write!(module, ~S'''
      defmodule Welcome do
        use MjmlEEx

        def render(assigns) do
          ~MJML"""
          <mj-column><mj-text>Hi {@name}</mj-text></mj-column>
          """
        end
      end
      ''')

      for file <- [template, module] do
        {formatter, _opts} =
          Format.formatter_for_file(file, dot_formatter: Path.join(tmp_dir, ".formatter.exs"))

        File.write!(file, formatter.(File.read!(file)))
      end

      assert File.read!(template) == "<mj-column>\n  <mj-text>Hi</mj-text>\n</mj-column>\n"

      assert File.read!(module) =~
               "    ~MJML\"\"\"\n    <mj-column>\n      <mj-text>Hi {@name}</mj-text>\n    </mj-column>\n    \"\"\""
    end
  end

  describe "the corpus" do
    for fixture <- Path.wildcard(Path.join(@corpus_dir, "{compare,template}/*.mjml")) do
      @fixture fixture

      test "#{Path.relative_to(fixture, @corpus_dir)} is formatted idempotently and renders the same HTML" do
        source = File.read!(@fixture)
        formatted = format(source)

        assert format(formatted) == formatted
        assert Mjml.to_html(formatted) == Mjml.to_html(source)
      end
    end
  end

  describe "generated templates" do
    # FORMATTER_RUNS=5000 mix test test/mjml_eex/formatter_test.exs for a longer run
    @runs String.to_integer(System.get_env("FORMATTER_RUNS", "150"))

    # Valid MJML documents with random whitespace and attribute layouts
    defp separator, do: member_of(["", " ", "\n", "\n\n", "\n    ", "\t", "\r\n", " \n "])
    defp words, do: list_of(member_of(~w(Hello there you <b>bold</b> <br> &amp; a-b)), min_length: 1, max_length: 6)

    defp attribute_block(attrs) do
      gen all(layout <- member_of([:inline, :lines])) do
        sep = if layout == :inline, do: " ", else: "\n  "
        Enum.map_join(attrs, "", fn {name, value} -> ~s(#{sep}#{name}="#{value}") end)
      end
    end

    defp leaf do
      one_of([
        gen all(words <- words(), sep <- separator(), attrs <- attribute_block([{"align", "center"}])) do
          "<mj-text#{attrs}>#{sep}#{Enum.join(words, " ")}#{sep}</mj-text>"
        end,
        gen all(
              attrs <- attribute_block([{"src", "https://example.com/a.png"}, {"alt", ""}]),
              closing <- member_of(["/>", " />", "></mj-image>"])
            ) do
          "<mj-image#{attrs}#{closing}"
        end,
        gen all(words <- words()) do
          ~s(<mj-button href="https://example.com">#{Enum.join(words, " ")}</mj-button>)
        end,
        constant("<mj-divider />"),
        constant("<mj-raw><!--[if mso]><table><![endif]--></mj-raw>")
      ])
    end

    defp container(tag, children_gen, max) do
      gen all(
            children <- list_of(children_gen, min_length: 1, max_length: max),
            seps <- list_of(separator(), length: length(children) + 1)
          ) do
        body = Enum.zip(seps, children) |> Enum.map_join(fn {sep, child} -> sep <> child end)
        "<#{tag}>#{body}#{List.last(seps)}</#{tag}>"
      end
    end

    defp document do
      gen all(
            sections <-
              list_of(container("mj-section", container("mj-column", leaf(), 4), 2), min_length: 1, max_length: 3),
            sep <- separator(),
            comment? <- boolean()
          ) do
        comment = if comment?, do: "<!-- note -->#{sep}", else: ""
        sections = if comment?, do: Enum.map(sections, &(&1 <> "<!-- end of section -->")), else: sections
        "<mjml>#{sep}<mj-body>#{comment}#{Enum.join(sections, sep)}</mj-body>#{sep}</mjml>"
      end
    end

    property "are formatted idempotently and render the same HTML, up to whitespace mrml copies between components" do
      check all(source <- document(), max_runs: @runs) do
        formatted = format(source)
        assert format(formatted) == formatted
        assert_same_html(source, formatted)
      end
    end

    property "with expressions are formatted idempotently" do
      check all(source <- document(), max_runs: @runs) do
        source =
          source
          |> String.replace("<mj-section>", ~s(<mj-section :if={@show}>), global: false)
          |> String.replace("Hello", "{@name}")
          |> String.replace("</mj-column>", "</mj-column><%= @extra %>", global: false)
          |> String.replace("</mj-section>", "</mj-section>{@footer}<!-- after -->", global: false)

        formatted = format(source)
        assert format(formatted) == formatted
      end
    end
  end
end
