defmodule MjmlEEx.CoreComponentsTest do
  # Themes set with Theme.put/1 are per process
  use ExUnit.Case, async: true

  import MjmlEEx, only: [sigil_MJML: 2]
  import MjmlEEx.CoreComponents

  alias MjmlEEx.Theme

  doctest MjmlEEx.CoreComponents

  @default %Theme{}

  # Puts rendered components where they belong in a document, and checks the document is
  # valid MJML that mjml_nif compiles. Returns the MJML.
  defp in_column(rendered), do: in_body("<mj-section><mj-column>#{rendered}</mj-column></mj-section>")

  defp in_body(rendered) do
    mjml = "<mjml><mj-body>#{rendered}</mj-body></mjml>"
    assert_compiles(mjml)
  end

  defp assert_compiles(mjml) do
    assert :ok = MjmlEEx.validate(mjml)
    assert MjmlEEx.to_html(mjml) =~ "</html>"
    mjml
  end

  describe "email/1" do
    test "renders a whole document with the theme" do
      assigns = %{}

      mjml =
        ~MJML"""
        <.email title="Your receipt" preview="Thanks!" lang="fr">
          <:head><mj-font name="Inter" href="https://example.com/inter.css" /></:head>
          <.card><.text>Hello</.text></.card>
        </.email>
        """
        |> to_string()
        |> assert_compiles()

      assert mjml =~ ~s(<mjml lang="fr">)
      assert mjml =~ "<mj-title>Your receipt</mj-title>"
      assert mjml =~ "<mj-preview>Thanks!</mj-preview>"
      assert mjml =~ ~s(<mj-all font-family="#{@default.font_family}" />)
      assert mjml =~ ~s(<mj-font name="Inter" href="https://example.com/inter.css" />)
      assert mjml =~ ~s(<mj-body background-color="#{@default.background}" width="600px">)
      assert mjml =~ ">Hello</mj-text>"
    end

    test "leaves out the title and preview when they aren't given" do
      assigns = %{}
      mjml = assert_compiles(to_string(~MJML"<.email><.card><.text>Hi</.text></.card></.email>"))

      refute mjml =~ "mj-title"
      refute mjml =~ "mj-preview"
    end

    test "escapes the title" do
      assigns = %{title: "Tom & Jerry <3"}
      mjml = assert_compiles(to_string(~MJML"<.email title={@title}><.card><.text>Hi</.text></.card></.email>"))
      assert mjml =~ "<mj-title>Tom &amp; Jerry &lt;3</mj-title>"
    end
  end

  describe "theme/1" do
    test "sets the document's defaults and link color" do
      assigns = %{}
      mjml = to_string(~MJML"<.theme />")

      assert mjml =~ ~s(<mj-text color="#{@default.text}" font-size="16px" line-height="24px" />)
      assert mjml =~ ~s(<mj-table color="#{@default.text}" font-size="16px" line-height="24px" />)
      assert mjml =~ "a { color: #{@default.primary}; }"

      assert_compiles("<mjml><mj-head>#{mjml}</mj-head><mj-body></mj-body></mjml>")
    end
  end

  describe "header/1" do
    test "renders a centered logo" do
      assigns = %{}
      mjml = in_body(~MJML|<.header logo="https://example.com/logo.png" logo_alt="Acme" href="https://example.com" />|)

      assert mjml =~
               ~s(<mj-image src="https://example.com/logo.png" alt="Acme" width="120px" href="https://example.com" align="center" padding="0 25px" />)

      refute mjml =~ "mj-navbar"
    end

    test "checks logo_width as the logo's width" do
      assigns = %{}

      assert_raise ArgumentError, ~r/header\/1's logo_width: Attribute width has invalid value: big/, fn ->
        ~MJML|<.header logo="https://example.com/logo.png" title="Acme" logo_width="big" />|
      end
    end

    test "uses the title as the logo's alternative text, unless logo_alt is given" do
      assigns = %{}
      mjml = in_body(~MJML|<.header logo="https://example.com/logo.png" title="Acme" />|)
      assert mjml =~ ~s(<mj-image src="https://example.com/logo.png" alt="Acme")

      assert_raise ArgumentError, ~r/header\/1 needs a logo_alt \(or a title\)/, fn ->
        ~MJML|<.header logo="https://example.com/logo.png" href="https://example.com" />|
      end
    end

    test "renders a title, linked when there's an href" do
      assigns = %{}
      mjml = in_body(~MJML|<.header title="Acme" align="left" />|)
      assert mjml =~ ~s(align="left")
      assert mjml =~ "<span>Acme</span>"

      mjml = in_body(~MJML|<.header title="Acme" href="https://example.com" />|)
      assert mjml =~ ~s(<a href="https://example.com" style="color:inherit;text-decoration:none;">Acme</a>)
    end

    test "puts links on the right of the logo" do
      assigns = %{}

      mjml =
        in_body(~MJML"""
        <.header logo="https://example.com/logo.png" logo_alt="Acme" padding="8px 0">
          <:link href="https://example.com/blog">Blog</:link>
          <:link href="https://example.com/help">Help</:link>
        </.header>
        """)

      assert mjml =~ ~s(<mj-section padding="8px 0">)
      assert mjml =~ "<mj-group>"
      assert mjml =~ ~s(align="left")
      assert mjml =~ ~s(<mj-navbar align="right")
      assert mjml =~ ~r/<mj-navbar-link href="https:\/\/example.com\/blog"[^>]*>\s*Blog\s*<\/mj-navbar-link>/
      assert mjml =~ ~r/<mj-navbar-link href="https:\/\/example.com\/help"[^>]*>\s*Help\s*<\/mj-navbar-link>/
    end
  end

  describe "card/1" do
    test "renders a column on the surface color" do
      assigns = %{}
      mjml = in_body(~MJML"<.card><.text>Hi</.text></.card>")

      assert mjml =~ ~s(<mj-section padding="0 0 16px">)
      assert mjml =~ ~s(<mj-column background-color="#FFFFFF" border-radius="8px" padding="24px 0">)
    end

    test "takes mj-column attributes over the theme's" do
      assigns = %{}
      mjml = in_body(~MJML|<.card background-color="#FAFAFA" css-class="promo"><.text>Hi</.text></.card>|)
      assert mjml =~ ~s(<mj-column background-color="#FAFAFA" border-radius="8px" padding="24px 0" css-class="promo">)
    end
  end

  describe "footer/1" do
    test "renders text, links and social icons" do
      assigns = %{}

      mjml =
        in_body(~MJML"""
        <.footer>
          Acme Inc.
          <:link href="https://example.com/unsubscribe">Unsubscribe</:link>
          <:link href="https://example.com/privacy">Privacy</:link>
          <:social name="github" href="https://github.com/acme" />
        </.footer>
        """)

      assert mjml =~ ~r/<mj-text align="center" color="#6B6B74"[^>]*>\s*Acme Inc.\s*<\/mj-text>/
      assert mjml =~ ~s(<a href="https://example.com/unsubscribe" style="color:#6B6B74;text-decoration:underline;">)
      assert mjml =~ "&nbsp;&middot;&nbsp;"
      assert mjml =~ ~s(<mj-social-element name="github" href="https://github.com/acme")
      assert mjml =~ ~s(padding="0 25px 12px")
    end

    test "leaves out the parts that aren't given" do
      assigns = %{}
      mjml = in_body(~MJML"<.footer>Acme Inc.</.footer>")
      refute mjml =~ "mj-social"
      refute mjml =~ "middot"

      mjml = in_body(~MJML|<.footer><:link href="/">Home</:link></.footer>|)
      assert length(String.split(mjml, "<mj-text")) == 2
      refute mjml =~ "middot"
    end
  end

  describe "heading/1" do
    test "renders h1, h2 and h3" do
      assigns = %{}

      mjml =
        in_column(~MJML"<.heading>One</.heading><.heading level={2}>Two</.heading><.heading level={3}>Three</.heading>")

      assert mjml =~
               ~r/<h1 style="margin:0;color:#18181B;font-family:[^;]+;font-size:28px;line-height:36px;font-weight:700;">One<\/h1>/

      assert mjml =~ ~r/<h2 style="[^"]*font-size:22px;line-height:30px;font-weight:700;">Two<\/h2>/
      assert mjml =~ ~r/<h3 style="[^"]*font-size:18px;line-height:26px;font-weight:600;">Three<\/h3>/
    end

    test "applies attributes to the heading's text too" do
      assigns = %{}
      mjml = in_column(~MJML|<.heading align="center" color="#E11D48" font-size="32px">Hi</.heading>|)

      assert mjml =~ ~r/<mj-text color="#E11D48"[^>]* font-size="32px"[^>]* align="center"/
      assert mjml =~ ~r/<h1 style="margin:0;color:#E11D48;[^"]*font-size:32px;/
    end

    test "uses the heading font" do
      assigns = %{}
      Theme.put(heading_font_family: "Georgia, serif")
      assert to_string(~MJML"<.heading>Hi</.heading>") =~ "font-family:Georgia, serif;"
    end

    test "rejects other levels" do
      assert_raise CompileError, ~r/attribute level for <.heading> must be one of \[1, 2, 3\], got: 4/, fn ->
        compile_email(BadLevel, "<.heading level={4}>Hi</.heading>")
      end
    end
  end

  describe "text/1" do
    test "renders the variants" do
      assigns = %{}

      assert in_column(~MJML"<.text>Body</.text>") =~
               ~s(<mj-text color="#3F3F46" font-size="16px" line-height="24px">Body</mj-text>)

      assert in_column(~MJML|<.text variant="lead">Lead</.text>|) =~
               ~s(<mj-text color="#3F3F46" font-size="18px" line-height="28px">Lead</mj-text>)

      assert in_column(~MJML|<.text variant="muted">Muted</.text>|) =~
               ~s(<mj-text color="#6B6B74" font-size="16px" line-height="24px">Muted</mj-text>)

      assert in_column(~MJML|<.text variant="small" align="center">Small</.text>|) =~
               ~s(<mj-text color="#6B6B74" font-size="14px" line-height="20px" align="center">Small</mj-text>)
    end

    test "keeps HTML in the content" do
      assigns = %{name: "<b>Alex</b>"}
      mjml = in_column(~MJML|<.text>Hi <strong>{@name}</strong>, <.link href="/x">go</.link></.text>|)

      assert mjml =~ "Hi <strong>&lt;b&gt;Alex&lt;/b&gt;</strong>"
      assert mjml =~ ~s(<a href="/x" style="color:#4F46E5;text-decoration:underline;">go</a>)
    end
  end

  describe "link/1" do
    test "passes target, rel and title to the a tag" do
      assigns = %{}
      mjml = to_string(~MJML|<.link href="https://example.com" target="_blank" rel="noopener">Acme</.link>|)

      assert mjml ==
               ~s(<a href="https://example.com" style="color:#4F46E5;text-decoration:underline;" rel="noopener" target="_blank">Acme</a>)
    end
  end

  describe "button/1" do
    test "renders the variants" do
      assigns = %{}

      assert in_column(~MJML|<.button href="/go">Go</.button>|) =~
               ~s(<mj-button href="/go" align="left" background-color="#4F46E5" color="#FFFFFF" border-radius="6px" font-size="16px" font-weight="600" line-height="20px" inner-padding="12px 24px">Go</mj-button>)

      assert in_column(~MJML|<.button href="/go" variant="secondary">Go</.button>|) =~
               ~s(background-color="#F4F4F5" color="#18181B" border-radius="6px")

      assert in_column(~MJML|<.button href="/go" variant="outline">Go</.button>|) =~
               ~s(background-color="#FFFFFF" color="#18181B" border="1px solid #E4E4E7" border-radius="6px")

      assert in_column(~MJML|<.button href="/go" variant="danger">Go</.button>|) =~
               ~s(background-color="#B91C1C" color="#FFFFFF" border-radius="6px")
    end

    test "fills the column when full_width" do
      assigns = %{}
      assert in_column(~MJML|<.button href="/go" full_width>Go</.button>|) =~ ~s( width="100%")
      refute in_column(~MJML|<.button href="/go">Go</.button>|) =~ "width="
    end

    test "takes mj-button attributes over the theme's" do
      assigns = %{attrs: [target: "_self"]}

      rendered =
        ~MJML|<.button href="/go" align="center" background-color="#000000" mj-class="big" {@attrs}>Go</.button>|

      mjml =
        assert_compiles("""
        <mjml>
          <mj-head><mj-attributes><mj-class name="big" font-size="20px" /></mj-attributes></mj-head>
          <mj-body><mj-section><mj-column>#{rendered}</mj-column></mj-section></mj-body>
        </mjml>
        """)

      assert mjml =~ ~s(align="center" background-color="#000000")
      assert mjml =~ ~s(mj-class="big")
      assert mjml =~ ~s(target="_self")
      refute mjml =~ "#4F46E5"
    end

    test "checks calls" do
      error =
        assert_raise CompileError, fn ->
          compile_email(BadButton, ~S|<.button href="/" variant="ghost" colour="red">Go</.button>|)
        end

      assert Exception.message(error) =~ ~s(attribute variant for <.button> must be one of)
      assert Exception.message(error) =~ ~s[unknown attribute colour for <.button> (did you mean "color"?)]

      assert_raise CompileError, ~r/missing required attribute href for <.button>/, fn ->
        compile_email(NoHref, "<.button>Go</.button>")
      end
    end
  end

  describe "divider/1 and spacer/1" do
    test "render a themed rule and space" do
      assigns = %{}

      assert in_column(~MJML"<.divider />") =~
               ~s(<mj-divider border-color="#E4E4E7" border-width="1px" padding="16px 25px" />)

      assert in_column(~MJML|<.divider padding="0" />|) =~ ~s(padding="0")
      assert in_column(~MJML"<.spacer />") =~ ~s(<mj-spacer height="24px" />)

      assert in_column(~MJML|<.spacer height="8px" css-class="gap" />|) =~
               ~s(<mj-spacer height="8px" css-class="gap" />)
    end
  end

  describe "callout/1" do
    test "renders the variants" do
      assigns = %{}

      for {variant, title, background} <- [
            {"info", @default.info, @default.info_background},
            {"success", @default.success, @default.success_background},
            {"warning", @default.warning, @default.warning_background},
            {"danger", @default.danger, @default.danger_background},
            {"neutral", @default.heading, @default.subtle}
          ] do
        mjml = in_column(~MJML|<.callout variant={variant} title="Note">Text</.callout>|)

        assert mjml =~ ~s(<td style="background-color:#{background};border-radius:6px;padding:16px 20px;">)
        assert mjml =~ ~s(<div style="color:#{title};font-weight:600;margin:0 0 4px;">Note</div>)
      end
    end

    test "defaults to info and leaves out a missing title" do
      assigns = %{}
      mjml = in_column(~MJML"<.callout>Text</.callout>")

      assert mjml =~ "background-color:#{@default.info_background}"
      refute mjml =~ "<div"
    end
  end

  describe "code/1" do
    test "renders the code large and centered" do
      assigns = %{code: "482913"}
      mjml = in_column(~MJML"<.code>{@code}</.code>")

      assert mjml =~
               ~r/<td style="background-color:#F4F4F5;[^"]*text-align:center;[^"]*letter-spacing:6px;">\s*482913\s*<\/td>/
    end
  end

  describe "table/1" do
    @rows [%{name: "Tea", price: "$3"}, %{name: "Cake", price: "$5"}]

    test "renders a header and a row for each item" do
      assigns = %{rows: @rows}

      mjml =
        in_column(~MJML"""
        <.table rows={@rows}>
          <:col :let={row} label="Item">{row.name}</:col>
          <:col :let={row} label="Price" align="right" width="30%">{row.price}</:col>
        </.table>
        """)

      assert mjml =~ ~r/<th align="left" style="[^"]*text-transform:uppercase;text-align:left;">\s*Item\s*<\/th>/
      assert mjml =~ ~r/<th align="right" width="30%" style="padding:0 0 8px 16px;[^"]*">\s*Price\s*<\/th>/
      assert mjml =~ ~r/<td align="left" style="padding:12px 0 12px 0;border-bottom:1px solid #E4E4E7;[^"]*">\s*Tea/
      assert mjml =~ ~r/<td align="right" width="30%" style="padding:12px 0 12px 16px;border-bottom:[^"]*">\s*\$3/
      # No rule under the last row
      assert mjml =~ ~r/<td align="left" style="padding:12px 0 12px 0;vertical-align:top;text-align:left;">\s*Cake/
    end

    test "leaves out the header when no column has a label" do
      assigns = %{rows: @rows}
      mjml = in_column(~MJML"<.table rows={@rows}><:col :let={row}>{row.name}</:col></.table>")

      refute mjml =~ "<th"
      assert mjml =~ "Cake"
    end

    test "takes any enumerable" do
      assigns = %{}
      mjml = in_column(~MJML"<.table rows={1..3}><:col :let={n}>Row {n}</:col></.table>")

      for n <- 1..3, do: assert(mjml =~ "Row #{n}")
    end

    test "renders no rows for an empty list" do
      assigns = %{}
      mjml = in_column(~MJML|<.table rows={[]}><:col label="Item">x</:col></.table>|)

      assert mjml =~ "<th"
      refute mjml =~ "<td"
    end
  end

  describe "list/1" do
    test "renders titles and values, with strong rows" do
      assigns = %{}

      mjml =
        in_column(~MJML"""
        <.list>
          <:item title="Subtotal">$40.00</:item>
          <:item title="Total" strong>$45.00</:item>
        </.list>
        """)

      assert mjml =~
               ~s(<td style="padding:6px 16px 6px 0;color:#6B6B74;vertical-align:top;">Subtotal</td>)

      assert mjml =~
               ~s(<td align="right" style="padding:6px 0;color:#18181B;text-align:right;vertical-align:top;">$40.00</td>)

      assert mjml =~
               ~s(<td style="padding:6px 16px 6px 0;padding-top:12px;border-top:1px solid #E4E4E7;color:#18181B;font-weight:600;vertical-align:top;">Total</td>)
    end
  end

  describe "accordion/1" do
    test "renders an element for each item" do
      assigns = %{}

      mjml =
        in_column(~MJML"""
        <.accordion>
          <:item title="Shipping?">3 to 5 days.</:item>
          <:item title="Returns?">Within <b>30</b> days.</:item>
        </.accordion>
        """)

      assert mjml =~ ~s(<mj-accordion border="1px solid #E4E4E7" padding="10px 25px">)
      assert mjml =~ ~r/<mj-accordion-title [^>]*>Shipping\?<\/mj-accordion-title>/
      assert mjml =~ ~r/<mj-accordion-text [^>]*>Within <b>30<\/b> days.<\/mj-accordion-text>/
    end
  end

  describe "navbar/1" do
    test "renders links" do
      assigns = %{}

      mjml =
        in_column(~MJML"""
        <.navbar align="left">
          <:link href="/blog">Blog</:link>
        </.navbar>
        """)

      assert mjml =~ ~s(<mj-navbar align="left">)

      assert mjml =~
               ~r/<mj-navbar-link href="\/blog" color="#18181B" font-size="14px" font-weight="600" line-height="20px" padding="8px 12px" text-decoration="none" text-transform="none">\s*Blog\s*<\/mj-navbar-link>/
    end
  end

  describe "spacer/1" do
    test "renders 24px of space by default, and checks the height like an mj-spacer's" do
      assigns = %{}
      assert in_column(~MJML|<.spacer />|) =~ ~s(<mj-spacer height="24px" />)
      assert in_column(~MJML|<.spacer height="40px" />|) =~ ~s(<mj-spacer height="40px" />)

      assert_raise CompileError, ~r/Attribute height has invalid value: big .*\(for <.spacer>\)/, fn ->
        Code.compile_string("""
        defmodule MjmlEEx.CoreComponentsTest.BadSpacer do
          use MjmlEEx
          import MjmlEEx.CoreComponents
          def render(assigns), do: ~MJML'<.spacer height="big" />'
        end
        """)
      end
    end
  end

  describe "social/1" do
    test "renders muted icons" do
      assigns = %{}

      mjml =
        in_column(~MJML"""
        <.social>
          <:link name="github" href="https://github.com/acme">GitHub</:link>
          <:link name="mastodon" href="https://mastodon.social/@acme" src="https://example.com/mastodon.png" />
        </.social>
        """)

      assert mjml =~
               ~r/<mj-social-element name="github" href="https:\/\/github.com\/acme" alt="github" background-color="#6B6B74">\s*GitHub\s*<\/mj-social-element>/

      assert mjml =~ ~s(src="https://example.com/mastodon.png")
    end

    test "uses the networks' colors with brand_colors" do
      assigns = %{}
      mjml = in_column(~MJML|<.social brand_colors><:link name="x" href="https://x.com/acme" /></.social>|)
      refute mjml =~ "background-color"
    end

    test "links every network to its href, not to a page that shares it" do
      networks = ~w(facebook twitter x google pinterest linkedin tumblr xing github instagram)
      assigns = %{networks: networks}

      html =
        MjmlEEx.to_html(
          in_column(~MJML"""
          <.social>
            <:link :for={name <- @networks} name={name} href={"https://#{name}.example.com/acme"} />
          </.social>
          """)
        )

      hrefs = Regex.scan(~r/<a href="([^"]*)"/, html, capture: :all_but_first) |> List.flatten() |> Enum.uniq()

      assert hrefs == Enum.map(networks, &"https://#{&1}.example.com/acme")
      assert html =~ ~s(alt="linkedin")
      assert html =~ "linkedin.png"
    end
  end

  describe "hero/1" do
    test "renders a section in the primary color, with light content" do
      assigns = %{}

      mjml =
        in_body(~MJML"""
        <.hero>
          <.heading>Hello</.heading>
          <.text variant="small">Small</.text>
          <.button href="/go">Go</.button>
        </.hero>
        """)

      assert mjml =~
               ~s(<mj-section css-class="mjml-eex-hero-primary" background-color="#4F46E5" border-radius="8px" padding="40px 0">)

      assert mjml =~ ~s(<mj-section padding="0 0 16px" />)
      assert mjml =~ ~s(<h1 style="margin:0;color:#FFFFFF;)
      # Small text is a mix of the text and background colors
      assert mjml =~ ~s(<mj-text color="#DCDAFA" font-size="14px")
      # Buttons swap the colors
      assert mjml =~ ~s(<mj-button href="/go" align="left" background-color="#FFFFFF" color="#4F46E5")
    end

    test "styles plain links in its text with the hero's foreground color" do
      assigns = %{}

      mjml =
        MjmlEEx.to_mjml(~MJML"""
        <.email>
          <.hero css-class="promo"><.text>Read <a href="/docs">the docs</a></.text></.hero>
          <.hero variant="surface"><.text>Plain</.text></.hero>
        </.email>
        """)

      assert mjml =~ ~s(<mj-section css-class="mjml-eex-hero-primary promo")
      assert mjml =~ ".mjml-eex-hero-primary a { color: #FFFFFF; text-decoration: underline; }"
      assert mjml =~ ".mjml-eex-hero-dark a { color: #FFFFFF; text-decoration: underline; }"
      refute mjml =~ "mjml-eex-hero-surface"
      assert MjmlEEx.to_html(mjml) =~ ~s(class="mjml-eex-hero-primary promo")
    end

    test "keeps a background image's URL inside its CSS url('...')" do
      assigns = %{image: "https://acme.com/o'brien.png"}
      html = MjmlEEx.to_html(in_body(~MJML|<.hero background_image={@image}><.text>Sale</.text></.hero>|))

      assert html =~ "url('https://acme.com/o%27brien.png')"
      refute html =~ "o'brien"
    end

    test "renders a dark hero with a background image" do
      assigns = %{}

      mjml =
        in_body(~MJML"""
        <.hero variant="dark" background_image="https://acme.com/sale.png" padding="56px 0">
          <.heading>Sale</.heading>
        </.hero>
        """)

      assert mjml =~
               ~s(<mj-section css-class="mjml-eex-hero-dark" background-color="#18181B" background-url="https://acme.com/sale.png" background-size="cover" background-repeat="no-repeat" background-position="center center" border-radius="8px" padding="56px 0">)

      assert mjml =~ ~s(<h1 style="margin:0;color:#FFFFFF;)
    end

    test "styles the content of a surface hero with the theme" do
      assigns = %{}
      mjml = in_body(~MJML|<.hero variant="surface"><.heading>Hello</.heading></.hero>|)

      assert mjml =~ ~s(<mj-section background-color="#FFFFFF")
      assert mjml =~ ~s(<h1 style="margin:0;color:#18181B;)
    end

    test "puts the theme back after its content" do
      assigns = %{}
      Theme.put(primary: "#E11D48")

      mjml = to_string(~MJML"<.hero><.heading>In</.heading></.hero><.card><.heading>Out</.heading></.card>")

      assert mjml =~
               ~s(color:#18181B;font-family:#{@default.font_family};font-size:28px;line-height:36px;font-weight:700;">Out)

      assert Theme.current().primary == "#E11D48"

      Theme.put(nil)
      assigns = %{fail: true}
      assert_raise RuntimeError, "boom", fn -> ~MJML|<.hero>{if @fail, do: raise("boom")}</.hero>| end
      assert Theme.current() == @default
    end

    test "mixes rgb() colors, and falls back for colors it can't mix" do
      assigns = %{}

      Theme.put(primary: "rgb(79, 70, 229)")
      assert to_string(~MJML|<.hero><.text variant="small">Hi</.text></.hero>|) =~ ~s(color="#DCDAFA")

      Theme.put(primary: "indigo")
      assert to_string(~MJML|<.hero><.text variant="small">Hi</.text></.hero>|) =~ ~s(color="#FFFFFF")
    end
  end

  describe "badge/1" do
    test "renders a tint of the primary color" do
      assigns = %{}

      assert in_column(~MJML"<.badge>New</.badge>") =~
               ~s(<mj-text font-size="13px" line-height="20px" padding="10px 25px 0"><span style="display:inline-block;padding:4px 10px;border-radius:999px;background-color:#EAE9FC;color:#4F46E5;font-weight:600;">New</span></mj-text>)
    end

    test "renders the variants, soft and solid" do
      assigns = %{}

      for {variant, solid, color, background} <- [
            {"neutral", false, @default.heading, @default.subtle},
            {"warning", false, @default.warning, @default.warning_background},
            {"info", false, @default.info, @default.info_background},
            {"primary", true, @default.primary_text, @default.primary},
            {"neutral", true, @default.surface, @default.heading},
            {"danger", true, @default.surface, @default.danger},
            {"success", true, @default.surface, @default.success}
          ] do
        mjml = in_column(~MJML"<.badge variant={variant} solid={solid}>Label</.badge>")
        assert mjml =~ "background-color:#{background};color:#{color};"
      end
    end

    test "passes attributes to the mj-text" do
      assigns = %{}
      mjml = in_column(~MJML|<.badge align="center" text-transform="uppercase">New</.badge>|)

      assert mjml =~
               ~s(<mj-text font-size="13px" line-height="20px" padding="10px 25px 0" align="center" text-transform="uppercase">)
    end
  end

  describe "text/1 eyebrow" do
    test "renders a small uppercase label in the primary color" do
      assigns = %{}

      assert in_column(~MJML|<.text variant="eyebrow">News</.text>|) =~
               ~s(<mj-text color="#4F46E5" font-size="13px" line-height="20px" font-weight="600" letter-spacing="0.5px" text-transform="uppercase" padding="10px 25px 0">News</mj-text>)
    end
  end

  describe "avatar/1" do
    test "renders initials in a circle" do
      assigns = %{}

      assert in_column(~MJML|<mj-text><.avatar name="Maya Patel" /></mj-text>|) =~
               ~s(<span style="display:inline-block;width:48px;height:48px;border-radius:50%;vertical-align:middle;background-color:#4F46E5;color:#FFFFFF;font-size:18px;line-height:48px;font-weight:700;text-align:center;">MP</span>)

      assert in_column(~MJML|<mj-text><.avatar name="tom" size={32} /></mj-text>|) =~
               ~r/width:32px;.*font-size:12px;line-height:32px;.*>T<\/span>/

      assert in_column(~MJML|<mj-text><.avatar name="jo de la cruz" /></mj-text>|) =~ ">JD</span>"
    end

    test "renders a photo" do
      assigns = %{}

      assert in_column(~MJML|<mj-text><.avatar name="Maya" src="https://acme.com/maya.png" size={64} /></mj-text>|) =~
               ~s(<img src="https://acme.com/maya.png" alt="Maya" width="64" height="64" style="display:inline-block;width:64px;height:64px;border-radius:50%;vertical-align:middle;">)
    end
  end

  describe "blockquote/1" do
    test "renders the quote and who said it" do
      assigns = %{}
      mjml = in_column(~MJML|<.blockquote author="Sam Lee" role="COO">It <em>works</em>.</.blockquote>|)

      assert mjml =~ ~s(<td style="background-color:#{@default.subtle};border-radius:6px;padding:20px 24px;">)
      assert mjml =~ "&ldquo;It <em>works</em>.&rdquo;</div>"
      assert mjml =~ ~r/<strong>Sam Lee<\/strong><span>, COO<\/span>/

      mjml =
        in_column(~MJML"""
        <.blockquote>
          Hi
        </.blockquote>
        """)

      assert mjml =~ "&ldquo;Hi&rdquo;"
      refute mjml =~ "<strong>"
    end
  end

  describe "checklist/1" do
    test "renders an item a row, with a check mark" do
      assigns = %{}
      mjml = in_column(~MJML"<.checklist><:item>One</:item><:item><b>Two</b></:item></.checklist>")

      assert mjml =~
               ~s(<td style="width:28px;padding:4px 0;vertical-align:top;color:#4F46E5;font-weight:700;">&#10003;</td>)

      assert mjml =~ ~s(<td style="padding:4px 0;vertical-align:top;">One</td>)
      assert mjml =~ ~s(<td style="padding:4px 0;vertical-align:top;"><b>Two</b></td>)
    end
  end

  describe "steps/1" do
    test "numbers the steps" do
      assigns = %{}

      mjml =
        in_column(~MJML"""
        <.steps>
          <:step title="Create a project">Projects hold your work.</:step>
          <:step title="Invite your team" />
        </.steps>
        """)

      assert mjml =~
               ~r/>1<\/div>.*Create a project<\/div>\s*<div style="color:#6B6B74;">Projects hold your work.<\/div>.*>2<\/div>/s

      assert mjml =~ "Invite your team</div>"
    end

    test "shows steps without titles in the text color" do
      assigns = %{}
      mjml = in_column(~MJML"<.steps><:step>Automate reports</:step></.steps>")

      assert mjml =~ "<div>Automate reports</div>"
      refute mjml =~ "font-weight:600"
    end
  end

  describe "theming" do
    test "components use the process's theme" do
      assigns = %{}
      Theme.put(primary: "#E11D48", button_radius: "999px", surface: "#FAFAF9")

      assert to_string(~MJML|<.button href="/">Go</.button>|) =~
               ~s(background-color="#E11D48" color="#FFFFFF" border-radius="999px")

      assert to_string(~MJML"<.card><.text>Hi</.text></.card>") =~ ~s(background-color="#FAFAF9")
      assert to_string(~MJML"<.theme />") =~ "a { color: #E11D48; }"
    end
  end

  test "a complete email compiles to HTML" do
    defmodule Receipt do
      use MjmlEEx
      import MjmlEEx.CoreComponents

      attr :items, :list, required: true

      def render(assigns) do
        ~MJML"""
        <.email title="Your receipt" preview="Thanks for your order">
          <.header title="Acme"><:link href="/orders">Orders</:link></.header>
          <.card>
            <.heading>Thanks for your order!</.heading>
            <.table rows={@items}>
              <:col :let={item} label="Item">{item.name}</:col>
              <:col :let={item} label="Price" align="right">{item.price}</:col>
            </.table>
            <.list><:item title="Total" strong>$8</:item></.list>
            <.callout variant="success">It ships tomorrow.</.callout>
            <.button href="/orders/1">View order</.button>
          </.card>
          <.footer>Acme Inc.<:link href="/unsubscribe">Unsubscribe</:link></.footer>
        </.email>
        """
      end
    end

    items = [%{name: "Tea", price: "$3"}, %{name: "Cake", price: "$5"}]
    html = Receipt.to_html(items: items)

    assert html =~ "Thanks for your order!"
    assert html =~ "Cake"
    assert html =~ "It ships tomorrow."
    assert :ok = MjmlEEx.validate(MjmlEEx.to_mjml(Receipt.render(items: items)))
  end

  test "a layout can render the document" do
    defmodule Layout do
      use MjmlEEx
      import MjmlEEx.CoreComponents

      def render(assigns) do
        ~MJML"""
        <.email title={@title}>
          <.header title="Acme" />
          {@inner_content}
          <.footer>Acme Inc.</.footer>
        </.email>
        """
      end
    end

    defmodule WithLayout do
      use MjmlEEx, layout: MjmlEEx.CoreComponentsTest.Layout
      import MjmlEEx.CoreComponents

      def render(assigns) do
        ~MJML"""
        <.card><.text>Hello {@name}</.text></.card>
        """
      end
    end

    mjml = MjmlEEx.to_mjml(WithLayout.render(title: "Hi", name: "Alex"))
    assert :ok = MjmlEEx.validate(mjml)
    assert mjml =~ "<mj-title>Hi</mj-title>"
    assert WithLayout.to_html(title: "Hi", name: "Alex") =~ "Hello Alex"
  end

  defp compile_email(name, body) do
    Code.compile_string(
      """
      defmodule MjmlEEx.CoreComponentsTest.#{name} do
        use MjmlEEx
        import MjmlEEx.CoreComponents
        def render(assigns), do: ~MJML'#{body}'
      end
      """,
      "email.ex"
    )
  end
end
