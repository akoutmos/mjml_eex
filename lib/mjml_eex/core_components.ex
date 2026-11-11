defmodule MjmlEEx.CoreComponents do
  @moduledoc """
  Ready-made components for clean, consistent emails: the document, cards, headings, text,
  buttons, tables, callouts and more, styled with `MjmlEEx.Theme`.

  Import them in your email modules (or in your own components module):

  ```elixir
  defmodule MyApp.Emails.Welcome do
    use MjmlEEx
    import MjmlEEx.CoreComponents

    def render(assigns) do
      ~MJML\"\"\"
      <.email title="Welcome to Acme" preview="Your account is ready">
        <.header logo="https://acme.com/logo.png" logo_alt="Acme" />
        <.card>
          <.heading>Welcome, {@name}!</.heading>
          <.text>Your account is ready. Finish setting it up to start inviting your team.</.text>
          <.button href={@setup_url}>Finish setup</.button>
        </.card>
        <.footer>Acme Inc., 1 Market St, San Francisco</.footer>
      </.email>
      \"\"\"
    end
  end
  ```

  ## Where components go

  The components fit together like MJML's own tags:

    * `email/1` is a whole document. Its content is the email's body.
    * `header/1`, `hero/1`, `card/1` and `footer/1` are sections: they go in `email/1`,
      `mj-body` or `mj-wrapper`.
    * `heading/1`, `text/1`, `button/1`, `badge/1`, `divider/1`, `spacer/1`, `callout/1`,
      `code/1`, `blockquote/1`, `table/1`, `list/1`, `checklist/1`, `steps/1`,
      `accordion/1`, `navbar/1` and `social/1` are content: they go in `hero/1`, `card/1` or
      `mj-column`.
    * `link/1` and `avatar/1` are HTML, for the text of `text/1` and `mj-text`, and table
      cells.
    * `theme/1` goes in `mj-head`, when you write the document yourself instead of using
      `email/1`.

  ## Changing the look

  Colors, fonts and sizes come from the theme. Change them for the whole app with
  `config :mjml_eex, :theme, ...`, or for one render with `MjmlEEx.Theme.put/1`. See
  `MjmlEEx.Theme` for every token.

  To change one component, pass it MJML attributes: they're passed through to the MJML tag the
  component renders, and take precedence over the theme's styles. A `button/1` renders an
  `mj-button`, so `<.button href="/" font-size="18px" inner-padding="16px 32px">` works. Each
  component's documentation says which tag it renders. Classes given with `mj-class` don't
  override the styles a component sets, since MJML gives attributes precedence over classes.

  To build your own components on top of these, wrap them in your own module:

  ```elixir
  attr :href, :string, required: true
  slot :inner_block, required: true

  def cta(assigns) do
    ~MJML\"\"\"
    <MjmlEEx.CoreComponents.button href={@href} align="center" full_width>
      {render_slot(@inner_block)}
    </MjmlEEx.CoreComponents.button>
    \"\"\"
  end
  ```
  """

  use MjmlEEx.Component

  alias MjmlEEx.Theme

  ## Document

  @doc """
  Renders a whole email: `mjml`, an `mj-head` with the theme (see `theme/1`), and an `mj-body`
  in the theme's background color and width.

  ```heex
  <.email title="Your receipt" preview="Thanks for your order!">
    <:head><mj-font name="Inter" href="https://fonts.googleapis.com/css2?family=Inter" /></:head>
    <.card>...</.card>
  </.email>
  ```

  ## Attributes

    * `title` - the document's title (`mj-title`).
    * `preview` - the preview text that inboxes show after the subject (`mj-preview`).
    * Other attributes are passed to `mjml`. Set `lang` to the email's language, such as
      `lang="en"`, so that screen readers read it in the right voice (without it, the email
      declares `lang="und"`, undetermined), and `dir="rtl"` for right-to-left languages.

  ## Slots

    * `inner_block` (required) - the content of `mj-body`: sections such as `header/1`,
      `card/1` and `footer/1`, or `mj-section` and `mj-wrapper`.
    * `head` - more content for `mj-head`, such as `mj-font`, `mj-style` or `mj-attributes`.
  """
  @spec email(map()) :: MjmlEEx.Rendered.t()
  attr :title, :string, default: nil
  attr :preview, :string, default: nil
  attr :rest, :global, for: "mjml"
  slot :head
  slot :inner_block, required: true

  def email(assigns) do
    assigns = assign(assigns, :theme, Theme.current())

    ~MJML"""
    <mjml {@rest}>
      <mj-head>
        <mj-title :if={@title}>{@title}</mj-title>
        <mj-preview :if={@preview}>{@preview}</mj-preview>
        <.theme />
        {render_slot(@head)}
      </mj-head>
      <mj-body background-color={@theme.background} width={@theme.width}>
        {render_slot(@inner_block)}
      </mj-body>
    </mjml>
    """
  end

  @doc """
  Renders the theme's defaults for the whole document, for `mj-head`: the font for every tag,
  the color, size and line height of `mj-text` and `mj-table`, and the color of links.

  `email/1` includes it. Use it when you write the `mjml` document yourself:

  ```heex
  <mjml>
    <mj-head>
      <mj-title>Your receipt</mj-title>
      <.theme />
    </mj-head>
    <mj-body>...</mj-body>
  </mjml>
  ```

  The other components don't need it: they're styled whether it's there or not.
  """
  @spec theme(map()) :: MjmlEEx.Rendered.t()
  def theme(assigns) do
    assigns = assign(assigns, :theme, Theme.current())

    ~MJML"""
    <mj-attributes>
      <mj-all font-family={@theme.font_family} />
      <mj-text color={@theme.text} font-size={@theme.font_size} line-height={@theme.line_height} />
      <mj-table color={@theme.text} font-size={@theme.font_size} line-height={@theme.line_height} />
    </mj-attributes>
    <mj-style>
      a { color: <%= @theme.primary %>; }
      .mjml-eex-hero-primary a { color: <%= @theme.primary_text %>; text-decoration: underline; }
      .mjml-eex-hero-dark a { color: <%= @theme.surface %>; text-decoration: underline; }
    </mj-style>
    """
  end

  ## Sections

  @doc """
  Renders the top of an email: a logo or a title, and optionally links.

  ```heex
  <.header logo="https://acme.com/logo.png" logo_alt="Acme" href="https://acme.com" />

  <.header title="Acme" align="left">
    <:link href="https://acme.com/blog">Blog</:link>
    <:link href="https://acme.com/help">Help</:link>
  </.header>
  ```

  With links, the logo or title is on the left and the links on the right.

  ## Attributes

    * `logo` - the URL of the logo image.
    * `logo_alt` - the logo's alternative text. Defaults to `title`.
    * `logo_width` - the width of the logo. Defaults to `"120px"`.
    * `title` - text to show when there's no logo.
    * `href` - the URL the logo or title links to.
    * `align` - `"left"`, `"center"` or `"right"`. Defaults to `"center"`.
    * Other attributes are passed to the `mj-section`.

  ## Slots

    * `link` - a link. Attributes: `href` (required).
  """
  @spec header(map()) :: MjmlEEx.Rendered.t()
  attr :logo, :string, default: nil
  attr :logo_alt, :string, default: nil
  attr :logo_width, :string, default: "120px"
  attr :title, :string, default: nil
  attr :href, :string, default: nil
  attr :align, :string, default: "center", values: ~w(left center right)
  attr :rest, :global, for: "mj-section"

  slot :link do
    attr :href, :string, required: true
  end

  def header(assigns) do
    theme = Theme.current()
    brand_align = if assigns.link == [], do: assigns.align, else: "left"

    assigns =
      assigns
      |> assign(:theme, theme)
      |> assign(:brand_align, brand_align)
      |> assign(:section, merge_attrs([padding: "32px 0 24px"], assigns.rest))
      |> assign(:title_style, style(color: "inherit", "text-decoration": "none"))

    ~MJML"""
    <mj-section {@section}>
      <mj-group :if={@link != []}>
        <mj-column width="40%" vertical-align="middle">
          <.brand {assigns} />
        </mj-column>
        <mj-column width="60%" vertical-align="middle">
          <mj-navbar align="right" padding="0 13px">
            <mj-navbar-link :for={link <- @link} href={link.href} {navbar_link_attrs(@theme)}>
              {render_slot(link)}
            </mj-navbar-link>
          </mj-navbar>
        </mj-column>
      </mj-group>
      <mj-column :if={@link == []} vertical-align="middle">
        <.brand {assigns} />
      </mj-column>
    </mj-section>
    """
  end

  defp brand(assigns) do
    ~MJML"""
    <mj-image
      :if={@logo}
      src={@logo}
      alt={@logo_alt || @title}
      width={@logo_width}
      href={@href}
      align={@brand_align}
      padding="0 25px"
    />
    <mj-text
      :if={!@logo && @title}
      align={@brand_align}
      color={@theme.heading}
      font-family={heading_font(@theme)}
      font-size="20px"
      font-weight="700"
      line-height="28px"
      padding="0 25px"
    >
      <a :if={@href} href={@href} style={@title_style}>{@title}</a>
      <span :if={!@href}>{@title}</span>
    </mj-text>
    """
  end

  @doc """
  Renders a card: a single column on the theme's `surface` color, with rounded corners. Cards
  are where an email's content usually goes.

  ```heex
  <.card>
    <.heading>Reset your password</.heading>
    <.text>Someone asked to reset the password for your account.</.text>
    <.button href={@reset_url}>Reset password</.button>
  </.card>
  ```

  Consecutive cards have a gap between them.

  ## Attributes

  Attributes are passed to the `mj-column`, such as `padding` or `background-color`.

  ## Slots

    * `inner_block` (required) - the card's content: components such as `heading/1` and
      `text/1`, or anything that goes in an `mj-column`.
  """
  @spec card(map()) :: MjmlEEx.Rendered.t()
  attr :rest, :global, for: "mj-column"
  slot :inner_block, required: true

  def card(assigns) do
    theme = Theme.current()

    assigns =
      assign(
        assigns,
        :column,
        merge_attrs(
          ["background-color": theme.surface, "border-radius": theme.radius, padding: "24px 0"],
          assigns.rest
        )
      )

    ~MJML"""
    <mj-section padding="0 0 16px">
      <mj-column {@column}>{render_slot(@inner_block)}</mj-column>
    </mj-section>
    """
  end

  @doc """
  Renders a hero: a banner in a bold color or with a background image, for the opening of
  announcements, invitations and sales.

  ```heex
  <.hero>
    <.text variant="eyebrow">Live webinar</.text>
    <.heading font-size="36px" line-height="44px">Ship faster with Acme workflows</.heading>
    <.text>Thursday, November 6 at 10:00 AM PT</.text>
    <.button href={@register_url}>Save my seat</.button>
  </.hero>

  <.hero variant="dark" background_image="https://acme.com/sale.jpg">...</.hero>
  ```

  Its content is styled for its background: on `"primary"` and `"dark"` heroes, the
  components inside use a version of the theme with light text, so headings, text, links,
  badges and codes are readable, and buttons are light with dark text. Plain `<a>` links in
  its text are styled to match by the theme's `<style>` (in `email/1`, or `theme/1`).

  Like cards, consecutive heroes and cards have a gap between them.

  ## Attributes

    * `variant` - `"primary"` (the theme's `primary` color), `"dark"` (the theme's `heading`
      color) or `"surface"` (the theme's `surface` color, like a card). Defaults to
      `"primary"`.
    * `background_image` - the URL of an image to cover the hero with. The variant's color
      shows while it loads and where it isn't supported, so pick an image of a similar
      color.
    * Other attributes are passed to the `mj-section`, such as `padding` or
      `background-position`.

  ## Slots

    * `inner_block` (required) - the hero's content: components such as `heading/1`,
      `text/1` and `button/1`, or anything that goes in an `mj-column`.
  """
  @spec hero(map()) :: MjmlEEx.Rendered.t()
  attr :variant, :string, default: "primary", values: ~w(primary dark surface)
  attr :background_image, :string, default: nil
  attr :rest, :global, for: "mj-section"
  slot :inner_block, required: true

  def hero(assigns) do
    theme = Theme.current()

    {background, content_theme} =
      case assigns.variant do
        "primary" -> {theme.primary, inverse_theme(theme, theme.primary, theme.primary_text)}
        "dark" -> {theme.heading, inverse_theme(theme, theme.heading, theme.surface)}
        "surface" -> {theme.surface, theme}
      end

    image = assigns.background_image

    # The theme's <style> (see theme/1) colors plain <a> links in primary and dark heroes
    # with the hero's foreground color, rather than the primary color
    css_class =
      [if(assigns.variant != "surface", do: "mjml-eex-hero-#{assigns.variant}"), assigns.rest[:"css-class"]]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")

    section =
      merge_attrs(
        [
          "css-class": if(css_class != "", do: css_class),
          "background-color": background,
          "background-url": image,
          "background-size": if(image, do: "cover"),
          "background-repeat": if(image, do: "no-repeat"),
          "background-position": if(image, do: "center center"),
          "border-radius": theme.radius,
          padding: "40px 0"
        ],
        Map.delete(assigns.rest, :"css-class")
      )

    assigns =
      assigns
      |> assign(:section, section)
      |> assign(:content, Theme.__with__(content_theme, fn -> render_slot(assigns.inner_block) end))

    # The empty section is the gap below, which can't be the hero's padding, as that has its
    # background
    ~MJML"""
    <mj-section {@section}>
      <mj-column>{@content}</mj-column>
    </mj-section>
    <mj-section padding="0 0 16px" />
    """
  end

  # The theme for content on a background color: the foreground color for text, links and
  # buttons, and mixes of the two for the quieter colors
  defp inverse_theme(theme, background, foreground) do
    tint = mix(foreground, background, 0.15, background)

    %{
      theme
      | primary: foreground,
        primary_text: background,
        background: background,
        surface: background,
        subtle: tint,
        text: foreground,
        heading: foreground,
        muted: mix(foreground, background, 0.8, foreground),
        border: mix(foreground, background, 0.3, foreground),
        info: foreground,
        info_background: tint,
        success: foreground,
        success_background: tint,
        warning: foreground,
        warning_background: tint,
        danger: foreground,
        danger_background: tint
    }
  end

  @doc """
  Renders the bottom of an email: small, centered text in the theme's `muted` color, with
  optional social icons above it and links below it.

  ```heex
  <.footer>
    Acme Inc., 1 Market St, San Francisco<br />
    You're receiving this because you signed up for Acme.
    <:link href={@unsubscribe_url}>Unsubscribe</:link>
    <:link href="https://acme.com/privacy">Privacy</:link>
    <:social name="x" href="https://x.com/acme" />
    <:social name="github" href="https://github.com/acme" />
  </.footer>
  ```

  ## Attributes

  Attributes are passed to the `mj-section`.

  ## Slots

    * `inner_block` - the text. It can contain HTML.
    * `link` - a link, shown below the text. Attributes: `href` (required).
    * `social` - a social icon, as in `social/1`. Attributes: `name` and `href` (required),
      and `src`.
  """
  @spec footer(map()) :: MjmlEEx.Rendered.t()
  attr :rest, :global, for: "mj-section"
  slot :inner_block

  slot :link do
    attr :href, :string, required: true
  end

  slot :social do
    attr :name, :string, required: true
    attr :href, :string, required: true
    attr :src, :string
  end

  def footer(assigns) do
    theme = Theme.current()
    # A footer with only links or icons still has an inner block, of whitespace
    text = render_slot(assigns.inner_block)

    assigns =
      assigns
      |> assign(:content, if(String.trim(to_string(text)) != "", do: text))
      |> assign(:section, merge_attrs([padding: "16px 0 32px"], assigns.rest))
      |> assign(:text, footer_text_attrs(theme))
      |> assign(:link_style, style(color: theme.muted, "text-decoration": "underline"))

    ~MJML"""
    <mj-section {@section}>
      <mj-column>
        {social(%{link: @social, padding: "0 25px 12px"})}
        <mj-text :if={@content} {@text}>{@content}</mj-text>
        <mj-text :if={@link != []} {@text}>
          <%= for {link, index} <- Enum.with_index(@link) do %>
            <span :if={index > 0}>&nbsp;&middot;&nbsp;</span>
            <a href={link.href} style={@link_style}>{render_slot(link)}</a>
          <% end %>
        </mj-text>
      </mj-column>
    </mj-section>
    """
  end

  defp footer_text_attrs(theme) do
    [
      align: "center",
      color: theme.muted,
      "font-size": "13px",
      "line-height": "20px",
      padding: "4px 25px"
    ]
  end

  ## Content

  @doc """
  Renders a heading (`h1`, `h2` or `h3`) in an `mj-text`.

  ```heex
  <.heading>Welcome to Acme</.heading>
  <.heading level={2} align="center">Your order</.heading>
  ```

  ## Attributes

    * `level` - `1`, `2` or `3`. Defaults to `1`.
    * Other attributes are passed to the `mj-text`, such as `align`, `color` or `padding`.

  ## Slots

    * `inner_block` (required) - the heading's text.
  """
  @spec heading(map()) :: MjmlEEx.Rendered.t()
  attr :level, :integer, default: 1, values: [1, 2, 3]
  attr :rest, :global, for: "mj-text"
  slot :inner_block, required: true

  def heading(assigns) do
    theme = Theme.current()

    {font_size, line_height, font_weight} =
      case assigns.level do
        1 -> {"28px", "36px", "700"}
        2 -> {"22px", "30px", "700"}
        3 -> {"18px", "26px", "600"}
      end

    attrs =
      merge_attrs(
        [
          color: theme.heading,
          "font-family": heading_font(theme),
          "font-size": font_size,
          "line-height": line_height,
          "font-weight": font_weight
        ],
        assigns.rest
      )

    # Email clients style headings themselves, so the h tag repeats the text styles
    heading_style =
      style(
        margin: "0",
        color: attrs[:color],
        "font-family": attrs[:"font-family"],
        "font-size": attrs[:"font-size"],
        "line-height": attrs[:"line-height"],
        "font-weight": attrs[:"font-weight"]
      )

    assigns = assigns |> assign(:attrs, attrs) |> assign(:heading_style, heading_style)

    ~MJML"""
    <mj-text {@attrs}>
      <h1 :if={@level == 1} style={@heading_style}>{render_slot(@inner_block)}</h1>
      <h2 :if={@level == 2} style={@heading_style}>{render_slot(@inner_block)}</h2>
      <h3 :if={@level == 3} style={@heading_style}>{render_slot(@inner_block)}</h3>
    </mj-text>
    """
  end

  @doc """
  Renders a paragraph of text in an `mj-text`.

  ```heex
  <.text>Thanks for signing up!</.text>
  <.text variant="small">If you didn't ask for this, you can ignore this email.</.text>
  <.text variant="eyebrow">Product news</.text>
  ```

  ## Attributes

    * `variant` - `"lead"` for a larger introduction, `"muted"` for secondary text,
      `"small"` for small print, or `"eyebrow"` for a short, uppercase label above a heading,
      in the theme's `primary` color. Without it, the text is body text.
    * Other attributes are passed to the `mj-text`, such as `align`, `color` or `padding`.

  ## Slots

    * `inner_block` (required) - the text. It can contain HTML.
  """
  @spec text(map()) :: MjmlEEx.Rendered.t()
  attr :variant, :string, values: ~w(lead muted small eyebrow)
  attr :rest, :global, for: "mj-text"
  slot :inner_block, required: true

  def text(assigns) do
    theme = Theme.current()

    defaults =
      case assigns[:variant] do
        nil -> [color: theme.text, "font-size": theme.font_size, "line-height": theme.line_height]
        "lead" -> [color: theme.text, "font-size": "18px", "line-height": "28px"]
        "muted" -> [color: theme.muted, "font-size": theme.font_size, "line-height": theme.line_height]
        "small" -> [color: theme.muted, "font-size": "14px", "line-height": "20px"]
        "eyebrow" -> eyebrow_attrs(theme)
      end

    assigns = assign(assigns, :attrs, merge_attrs(defaults, assigns.rest))

    ~MJML"""
    <mj-text {@attrs}>{render_slot(@inner_block)}</mj-text>
    """
  end

  defp eyebrow_attrs(theme) do
    [
      color: theme.primary,
      "font-size": "13px",
      "line-height": "20px",
      "font-weight": "600",
      "letter-spacing": "0.5px",
      "text-transform": "uppercase",
      padding: "10px 25px 0"
    ]
  end

  @doc """
  Renders a link in the theme's `primary` color, for the text of `text/1` and `mj-text`.

  ```heex
  <.text>Questions? <.link href="mailto:help@acme.com">Contact us</.link>.</.text>
  ```

  ## Attributes

    * `href` (required) - the URL.
    * `target`, `rel` and `title` are passed to the `a` tag.

  ## Slots

    * `inner_block` (required) - the link's text.
  """
  @spec link(map()) :: MjmlEEx.Rendered.t()
  attr :href, :string, required: true
  attr :rest, :global, include: ~w(target rel title)
  slot :inner_block, required: true

  def link(assigns) do
    theme = Theme.current()

    assigns =
      assigns
      |> assign(:style, style(color: theme.primary, "text-decoration": "underline"))
      |> assign(:attrs, merge_attrs([], assigns.rest))

    ~MJML"""
    <a href={@href} style={@style} {@attrs}>{render_slot(@inner_block)}</a>
    """
  end

  @doc """
  Renders a person's photo, or their initials in a circle in the theme's `primary` color, for
  the text of `text/1`, `mj-text` and table cells.

  ```heex
  <.avatar name="Maya Patel" />
  <.avatar name="Maya Patel" src={@photo_url} size={64} />
  ```

  Outlook on Windows shows the circle as a square.

  ## Attributes

    * `name` (required) - the person's name, for the initials and the photo's alternative
      text.
    * `src` - the URL of a square photo. Without it, the initials are shown.
    * `size` - the width and height in pixels. Defaults to `48`.
  """
  @spec avatar(map()) :: MjmlEEx.Rendered.t()
  attr :name, :string, required: true
  attr :src, :string, default: nil
  attr :size, :integer, default: 48

  def avatar(assigns) do
    theme = Theme.current()
    size = "#{assigns.size}px"

    photo_style =
      style(display: "inline-block", width: size, height: size, "border-radius": "50%", "vertical-align": "middle")

    initials_style =
      style(
        display: "inline-block",
        width: size,
        height: size,
        "border-radius": "50%",
        "vertical-align": "middle",
        "background-color": theme.primary,
        color: theme.primary_text,
        "font-size": "#{round(assigns.size * 0.375)}px",
        "line-height": size,
        "font-weight": "700",
        "text-align": "center"
      )

    assigns =
      assigns
      |> assign(:photo_style, photo_style)
      |> assign(:initials_style, initials_style)
      |> assign(:initials, initials(assigns.name))

    ~MJML"""
    <img :if={@src} src={@src} alt={@name} width={@size} height={@size} style={@photo_style} />
    <span :if={!@src} style={@initials_style}>{@initials}</span>
    """
  end

  # The first letters of the first two words
  defp initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  @doc """
  Renders a button (an `mj-button`).

  ```heex
  <.button href={@url}>View your order</.button>
  <.button href={@url} variant="secondary" align="center" full_width>Manage settings</.button>
  ```

  ## Attributes

    * `href` (required) - the URL the button links to.
    * `variant` - `"primary"` (in the theme's `primary` color), `"secondary"`, `"outline"` or
      `"danger"`. Defaults to `"primary"`.
    * `full_width` - make the button as wide as its column. Defaults to `false`.
    * Other attributes are passed to the `mj-button`, such as `align` (which defaults to
      `"left"`), `font-size` or `inner-padding`.

  ## Slots

    * `inner_block` (required) - the button's label.
  """
  @spec button(map()) :: MjmlEEx.Rendered.t()
  attr :href, :string, required: true
  attr :variant, :string, default: "primary", values: ~w(primary secondary outline danger)
  attr :full_width, :boolean, default: false
  attr :rest, :global, for: "mj-button"
  slot :inner_block, required: true

  def button(assigns) do
    theme = Theme.current()

    {background, color, border} =
      case assigns.variant do
        "primary" -> {theme.primary, theme.primary_text, nil}
        "secondary" -> {theme.subtle, theme.heading, nil}
        "outline" -> {theme.surface, theme.heading, "1px solid #{theme.border}"}
        "danger" -> {theme.danger, theme.surface, nil}
      end

    defaults = [
      align: "left",
      "background-color": background,
      color: color,
      border: border,
      "border-radius": theme.button_radius,
      "font-size": theme.font_size,
      "font-weight": "600",
      "line-height": "20px",
      "inner-padding": "12px 24px",
      width: if(assigns.full_width, do: "100%")
    ]

    assigns = assign(assigns, :attrs, merge_attrs(defaults, assigns.rest))

    ~MJML"""
    <mj-button href={@href} {@attrs}>{render_slot(@inner_block)}</mj-button>
    """
  end

  @doc """
  Renders a badge: a short label in a pill, such as "New" or "3 days left" (an `mj-text`).

  ```heex
  <.badge>New</.badge>
  <.badge variant="warning">3 days left in your trial</.badge>
  <.badge variant="danger" solid text-transform="uppercase">Sold out</.badge>
  ```

  ## Attributes

    * `variant` - `"primary"`, `"neutral"`, `"info"`, `"success"`, `"warning"` or `"danger"`.
      Defaults to `"primary"`. Badges have a light tint of the variant's color with text in
      the color, as in the theme's callouts.
    * `solid` - fill the badge with the variant's color instead, with light text. Defaults to
      `false`.
    * Other attributes are passed to the `mj-text`, such as `align`, `padding`,
      `text-transform` or `letter-spacing`.

  ## Slots

    * `inner_block` (required) - the label.
  """
  @spec badge(map()) :: MjmlEEx.Rendered.t()
  attr :variant, :string, default: "primary", values: ~w(primary neutral info success warning danger)
  attr :solid, :boolean, default: false
  attr :rest, :global, for: "mj-text"
  slot :inner_block, required: true

  def badge(assigns) do
    theme = Theme.current()

    {color, background} =
      case {assigns.variant, assigns.solid} do
        {"primary", false} -> {theme.primary, mix(theme.primary, theme.surface, 0.12, theme.subtle)}
        {"primary", true} -> {theme.primary_text, theme.primary}
        {"neutral", false} -> {theme.heading, theme.subtle}
        {"neutral", true} -> {theme.surface, theme.heading}
        {variant, false} -> {theme_color(theme, variant), theme_color(theme, "#{variant}_background")}
        {variant, true} -> {theme.surface, theme_color(theme, variant)}
      end

    pill_style =
      style(
        display: "inline-block",
        padding: "4px 10px",
        "border-radius": "999px",
        "background-color": background,
        color: color,
        "font-weight": "600"
      )

    assigns =
      assigns
      |> assign(:attrs, merge_attrs(["font-size": "13px", "line-height": "20px", padding: "10px 25px 0"], assigns.rest))
      |> assign(:pill_style, pill_style)

    ~MJML"""
    <mj-text {@attrs}><span style={@pill_style}>{render_slot(@inner_block)}</span></mj-text>
    """
  end

  defp theme_color(theme, name), do: Map.fetch!(theme, String.to_existing_atom(name))

  @doc """
  Renders a horizontal rule (an `mj-divider`) in the theme's `border` color.

  ```heex
  <.divider />
  ```

  ## Attributes

  Attributes are passed to the `mj-divider`, such as `padding` or `border-width`.
  """
  @spec divider(map()) :: MjmlEEx.Rendered.t()
  attr :rest, :global, for: "mj-divider"

  def divider(assigns) do
    theme = Theme.current()

    assigns =
      assign(
        assigns,
        :attrs,
        merge_attrs(["border-color": theme.border, "border-width": "1px", padding: "16px 25px"], assigns.rest)
      )

    ~MJML"""
    <mj-divider {@attrs} />
    """
  end

  @doc """
  Renders empty vertical space (an `mj-spacer`).

  ```heex
  <.spacer height="40px" />
  ```

  ## Attributes

    * `height` - defaults to `"24px"`.
    * Other attributes are passed to the `mj-spacer`.
  """
  @spec spacer(map()) :: MjmlEEx.Rendered.t()
  attr :height, :string, default: "24px"
  attr :rest, :global, for: "mj-spacer"

  def spacer(assigns) do
    assigns = assign(assigns, :attrs, merge_attrs([height: assigns.height], assigns.rest))

    ~MJML"""
    <mj-spacer {@attrs} />
    """
  end

  @doc """
  Renders a highlighted box with an optional title, for notes and warnings (an `mj-table`).

  ```heex
  <.callout title="This link expires in 24 hours">
    After that, you can ask for a new one from the sign-in page.
  </.callout>

  <.callout variant="danger" title="Your payment failed">
    Update your card to keep your subscription.
  </.callout>
  ```

  ## Attributes

    * `variant` - `"info"`, `"success"`, `"warning"`, `"danger"` or `"neutral"`. Defaults to
      `"info"`. The colors are the theme's matching tokens, such as `info` and
      `info_background`.
    * `title` - a title, shown in bold above the text.
    * Other attributes are passed to the `mj-table`, such as `padding`.

  ## Slots

    * `inner_block` (required) - the text. It can contain HTML.
  """
  @spec callout(map()) :: MjmlEEx.Rendered.t()
  attr :variant, :string, default: "info", values: ~w(info success warning danger neutral)
  attr :title, :string, default: nil
  attr :rest, :global, for: "mj-table"
  slot :inner_block, required: true

  def callout(assigns) do
    theme = Theme.current()

    {title_color, background} =
      case assigns.variant do
        "info" -> {theme.info, theme.info_background}
        "success" -> {theme.success, theme.success_background}
        "warning" -> {theme.warning, theme.warning_background}
        "danger" -> {theme.danger, theme.danger_background}
        "neutral" -> {theme.heading, theme.subtle}
      end

    assigns =
      assigns
      |> assign(:attrs, merge_attrs(box_attrs(theme), assigns.rest))
      |> assign(
        :cell_style,
        style("background-color": background, "border-radius": theme.button_radius, padding: "16px 20px")
      )
      |> assign(:title_style, style(color: title_color, "font-weight": "600", margin: "0 0 4px"))

    ~MJML"""
    <mj-table {@attrs}>
      <tr>
        <td style={@cell_style}>
          <div :if={@title} style={@title_style}>{@title}</div>
          {render_slot(@inner_block)}
        </td>
      </tr>
    </mj-table>
    """
  end

  @doc """
  Renders a code for the reader to copy, such as a verification or one-time code: large,
  spaced out and centered in a box (an `mj-table`).

  ```heex
  <.text>Enter this code to sign in:</.text>
  <.code>{@code}</.code>
  ```

  ## Attributes

  Attributes are passed to the `mj-table`, such as `padding`.

  ## Slots

    * `inner_block` (required) - the code.
  """
  @spec code(map()) :: MjmlEEx.Rendered.t()
  attr :rest, :global, for: "mj-table"
  slot :inner_block, required: true

  def code(assigns) do
    theme = Theme.current()

    # The letter spacing is also added after the last character, so the left padding
    # makes up for it to keep the code centered
    cell_style =
      style(
        "background-color": theme.subtle,
        "border-radius": theme.button_radius,
        padding: "16px 16px 16px 22px",
        "text-align": "center",
        color: theme.heading,
        "font-family": theme.monospace_font_family,
        "font-size": "30px",
        "line-height": "36px",
        "font-weight": "700",
        "letter-spacing": "6px"
      )

    assigns =
      assigns
      |> assign(:attrs, merge_attrs(box_attrs(theme), assigns.rest))
      |> assign(:cell_style, cell_style)

    ~MJML"""
    <mj-table {@attrs}>
      <tr>
        <td style={@cell_style}>{render_slot(@inner_block)}</td>
      </tr>
    </mj-table>
    """
  end

  @doc """
  Renders a quote, such as a customer's testimonial or a personal note, with who said it (an
  `mj-table`).

  ```heex
  <.blockquote author="Sam Lee" role="COO, Globex">
    Insights replaced three tools for us.
  </.blockquote>
  ```

  The quote marks are added around the text.

  ## Attributes

    * `author` - who said it.
    * `role` - the author's role or company, shown after their name.
    * Other attributes are passed to the `mj-table`, such as `padding`.

  ## Slots

    * `inner_block` (required) - the quote. It can contain HTML.
  """
  @spec blockquote(map()) :: MjmlEEx.Rendered.t()
  attr :author, :string, default: nil
  attr :role, :string, default: nil
  attr :rest, :global, for: "mj-table"
  slot :inner_block, required: true

  def blockquote(assigns) do
    theme = Theme.current()

    # The quote marks go right around the text, whatever whitespace the content has
    text = assigns.inner_block |> render_slot() |> to_string() |> String.trim()

    assigns =
      assigns
      |> assign(:text, %MjmlEEx.Rendered{mjml: text})
      |> assign(:attrs, merge_attrs(box_attrs(theme), assigns.rest))
      |> assign(
        :cell_style,
        style("background-color": theme.subtle, "border-radius": theme.button_radius, padding: "20px 24px")
      )
      |> assign(:quote_style, style(color: theme.heading, "font-size": "18px", "line-height": "28px"))
      |> assign(
        :author_style,
        style(color: theme.muted, "font-size": "14px", "line-height": "20px", "padding-top": "12px")
      )

    ~MJML"""
    <mj-table {@attrs}>
      <tr>
        <td style={@cell_style}>
          <div style={@quote_style}>&ldquo;{@text}&rdquo;</div>
          <div :if={@author} style={@author_style}>
            <strong>{@author}</strong><span :if={@role}>, {@role}</span>
          </div>
        </td>
      </tr>
    </mj-table>
    """
  end

  defp box_attrs(theme) do
    [
      cellpadding: "0",
      color: theme.text,
      "font-size": theme.font_size,
      "line-height": theme.line_height,
      padding: "10px 25px"
    ]
  end

  @doc """
  Renders a table of data (an `mj-table`), with a column for each `col` slot and a row for
  each item in `rows`.

  ```heex
  <.table rows={@order.items}>
    <:col :let={item} label="Item">{item.name}</:col>
    <:col :let={item} label="Qty" align="center" width="15%">{item.quantity}</:col>
    <:col :let={item} label="Price" align="right" width="25%">{item.price}</:col>
  </.table>
  ```

  The header row is only shown when a column has a label.

  ## Attributes

    * `rows` (required) - the rows, as a list or any other enumerable. Each `col` slot is
      rendered with the row, which it receives with `:let`.
    * Other attributes are passed to the `mj-table`, such as `padding` or `font-size`.

  ## Slots

    * `col` (required) - a column. Attributes: `label`, `align` (`"left"`, `"center"` or
      `"right"`) and `width`.
  """
  @spec table(map()) :: MjmlEEx.Rendered.t()
  attr :rows, :any, required: true
  attr :rest, :global, for: "mj-table"

  slot :col, required: true do
    attr :label, :string
    attr :align, :string, values: ~w(left center right)
    attr :width, :string
  end

  def table(assigns) do
    theme = Theme.current()
    rows = Enum.to_list(assigns.rows)

    assigns =
      assigns
      |> assign(:theme, theme)
      |> assign(:rows, rows)
      |> assign(:attrs, merge_attrs(box_attrs(theme), assigns.rest))
      |> assign(:header?, Enum.any?(assigns.col, & &1[:label]))
      |> assign(:last, length(rows) - 1)

    ~MJML"""
    <mj-table {@attrs}>
      <tr :if={@header?}>
        <th
          :for={{col, index} <- Enum.with_index(@col)}
          align={col[:align] || "left"}
          width={col[:width]}
          style={table_header_style(@theme, col, index)}
        >
          {col[:label]}
        </th>
      </tr>
      <tr :for={{row, row_index} <- Enum.with_index(@rows)}>
        <td
          :for={{col, index} <- Enum.with_index(@col)}
          align={col[:align] || "left"}
          width={col[:width]}
          style={table_cell_style(@theme, col, index, row_index == @last)}
        >
          {render_slot(col, row)}
        </td>
      </tr>
    </mj-table>
    """
  end

  defp table_header_style(theme, col, index) do
    style(
      padding: "0 0 8px #{cell_gap(index)}",
      "border-bottom": "1px solid #{theme.border}",
      color: theme.muted,
      "font-size": "12px",
      "line-height": "16px",
      "font-weight": "600",
      "letter-spacing": "0.05em",
      "text-transform": "uppercase",
      "text-align": col[:align] || "left"
    )
  end

  defp table_cell_style(theme, col, index, last?) do
    style(
      padding: "12px 0 12px #{cell_gap(index)}",
      "border-bottom": if(!last?, do: "1px solid #{theme.border}"),
      "vertical-align": "top",
      "text-align": col[:align] || "left"
    )
  end

  defp cell_gap(0), do: "0"
  defp cell_gap(_index), do: "16px"

  @doc """
  Renders a list of titles and values, such as the details or the totals of an order (an
  `mj-table`).

  ```heex
  <.list>
    <:item title="Subtotal">$40.00</:item>
    <:item title="Shipping">$5.00</:item>
    <:item title="Total" strong>$45.00</:item>
  </.list>
  ```

  ## Attributes

  Attributes are passed to the `mj-table`, such as `padding` or `font-size`.

  ## Slots

    * `item` (required) - a row, with the value as its content. Attributes: `title`
      (required), and `strong` to emphasize the row, with a rule above it.
  """
  @spec list(map()) :: MjmlEEx.Rendered.t()
  attr :rest, :global, for: "mj-table"

  slot :item, required: true do
    attr :title, :string, required: true
    attr :strong, :boolean
  end

  def list(assigns) do
    theme = Theme.current()

    assigns =
      assigns
      |> assign(:theme, theme)
      |> assign(:attrs, merge_attrs(box_attrs(theme), assigns.rest))

    ~MJML"""
    <mj-table {@attrs}>
      <tr :for={item <- @item}>
        <td style={list_cell_style(@theme, item, :title)}>{item.title}</td>
        <td align="right" style={list_cell_style(@theme, item, :value)}>{render_slot(item)}</td>
      </tr>
    </mj-table>
    """
  end

  defp list_cell_style(theme, item, part) do
    strong? = item[:strong] == true

    style(
      padding: if(part == :title, do: "6px 16px 6px 0", else: "6px 0"),
      "padding-top": if(strong?, do: "12px"),
      "border-top": if(strong?, do: "1px solid #{theme.border}"),
      color: if(strong? or part == :value, do: theme.heading, else: theme.muted),
      "font-weight": if(strong?, do: "600"),
      "text-align": if(part == :value, do: "right"),
      "vertical-align": "top"
    )
  end

  @doc """
  Renders a list with a check mark in the theme's `primary` color before each item, such as
  the features of a plan (an `mj-table`).

  ```heex
  <.checklist>
    <:item>Unlimited projects</:item>
    <:item>Priority support</:item>
  </.checklist>
  ```

  ## Attributes

  Attributes are passed to the `mj-table`, such as `padding`.

  ## Slots

    * `item` (required) - an item. It can contain HTML.
  """
  @spec checklist(map()) :: MjmlEEx.Rendered.t()
  attr :rest, :global, for: "mj-table"
  slot :item, required: true

  def checklist(assigns) do
    theme = Theme.current()

    assigns =
      assigns
      |> assign(:attrs, merge_attrs(box_attrs(theme), assigns.rest))
      |> assign(
        :mark_style,
        style(width: "28px", padding: "4px 0", "vertical-align": "top", color: theme.primary, "font-weight": "700")
      )

    ~MJML"""
    <mj-table {@attrs}>
      <tr :for={item <- @item}>
        <td style={@mark_style}>&#10003;</td>
        <td style="padding:4px 0;vertical-align:top;">{render_slot(item)}</td>
      </tr>
    </mj-table>
    """
  end

  @doc """
  Renders numbered steps, such as how to get started or an agenda (an `mj-table`). Each
  number is in a circle.

  ```heex
  <.steps>
    <:step title="Create a project">Projects keep your team's work in one place.</:step>
    <:step title="Invite your team">Everyone sees what's next.</:step>
  </.steps>

  <.steps>
    <:step>Automate your weekly reports</:step>
    <:step>Hand off work between teams</:step>
  </.steps>
  ```

  ## Attributes

  Attributes are passed to the `mj-table`, such as `padding`.

  ## Slots

    * `step` (required) - a step, with its text as its content. Attributes: `title`, shown in
      bold above the text, which is then in the theme's `muted` color.
  """
  @spec steps(map()) :: MjmlEEx.Rendered.t()
  attr :rest, :global, for: "mj-table"

  slot :step, required: true do
    attr :title, :string
  end

  def steps(assigns) do
    theme = Theme.current()

    number_style =
      style(
        width: "24px",
        height: "24px",
        "border-radius": "12px",
        "background-color": theme.subtle,
        color: theme.primary,
        "font-size": "13px",
        "line-height": "24px",
        "font-weight": "700",
        "text-align": "center"
      )

    assigns =
      assigns
      |> assign(:theme, theme)
      |> assign(:attrs, merge_attrs(box_attrs(theme), assigns.rest))
      |> assign(:number_style, number_style)
      |> assign(:title_style, style(color: theme.heading, "font-weight": "600"))

    ~MJML"""
    <mj-table {@attrs}>
      <tr :for={{step, number} <- Enum.with_index(@step, 1)}>
        <td style="width:40px;padding:6px 0;vertical-align:top;">
          <div style={@number_style}>{number}</div>
        </td>
        <td style="padding:6px 0;vertical-align:top;">
          <div :if={step[:title]} style={@title_style}>{step.title}</div>
          <div style={if step[:title], do: "color:#{@theme.muted};"}>{render_slot(step)}</div>
        </td>
      </tr>
    </mj-table>
    """
  end

  @doc """
  Renders an accordion (an `mj-accordion`): titles that expand to show their text.

  ```heex
  <.accordion>
    <:item title="When will my order arrive?">Most orders arrive within 3 to 5 days.</:item>
    <:item title="Can I return it?">Yes, within 30 days.</:item>
  </.accordion>
  ```

  Email clients that can't expand accordions show every item's text.

  The expand and collapse icons are MJML's, which are images hosted on imgur.com. Imgur isn't
  available everywhere (it blocks the UK, for example), so for emails to all your users, host
  your own icons and set them with `icon-wrapped-url` and `icon-unwrapped-url`.

  ## Attributes

  Attributes are passed to the `mj-accordion`, such as `border`, `padding`, or the icons'
  `icon-wrapped-url` and `icon-unwrapped-url`.

  ## Slots

    * `item` (required) - an item, with its text as its content. Attributes: `title`
      (required).
  """
  @spec accordion(map()) :: MjmlEEx.Rendered.t()
  attr :rest, :global, for: "mj-accordion"

  slot :item, required: true do
    attr :title, :string, required: true
  end

  def accordion(assigns) do
    theme = Theme.current()
    title = ["background-color": theme.surface, color: theme.heading, "font-size": theme.font_size, padding: "16px"]

    text = [
      "background-color": theme.surface,
      color: theme.text,
      "font-size": theme.font_size,
      "line-height": theme.line_height,
      padding: "0 16px 16px"
    ]

    assigns =
      assigns
      |> assign(:attrs, merge_attrs([border: "1px solid #{theme.border}", padding: "10px 25px"], assigns.rest))
      |> assign(:title, title)
      |> assign(:text, text)

    ~MJML"""
    <mj-accordion {@attrs}>
      <mj-accordion-element :for={item <- @item}>
        <mj-accordion-title {@title}>{item.title}</mj-accordion-title>
        <mj-accordion-text {@text}>{render_slot(item)}</mj-accordion-text>
      </mj-accordion-element>
    </mj-accordion>
    """
  end

  @doc """
  Renders a row of links (an `mj-navbar`).

  ```heex
  <.navbar>
    <:link href="https://acme.com/blog">Blog</:link>
    <:link href="https://acme.com/help">Help</:link>
  </.navbar>
  ```

  ## Attributes

  Attributes are passed to the `mj-navbar`, such as `align` (which defaults to `"center"`) or
  `hamburger`.

  ## Slots

    * `link` (required) - a link. Attributes: `href` (required).
  """
  @spec navbar(map()) :: MjmlEEx.Rendered.t()
  attr :rest, :global, for: "mj-navbar"

  slot :link, required: true do
    attr :href, :string, required: true
  end

  def navbar(assigns) do
    assigns =
      assigns
      |> assign(:theme, Theme.current())
      |> assign(:attrs, merge_attrs([align: "center"], assigns.rest))

    ~MJML"""
    <mj-navbar {@attrs}>
      <mj-navbar-link :for={link <- @link} href={link.href} {navbar_link_attrs(@theme)}>
        {render_slot(link)}
      </mj-navbar-link>
    </mj-navbar>
    """
  end

  defp navbar_link_attrs(theme) do
    [
      color: theme.heading,
      "font-size": "14px",
      "font-weight": "600",
      "line-height": "20px",
      padding: "8px 12px",
      "text-decoration": "none",
      "text-transform": "none"
    ]
  end

  @doc """
  Renders social icons (an `mj-social`), as round icons in the theme's `muted` color.

  ```heex
  <.social>
    <:link name="x" href="https://x.com/acme" />
    <:link name="github" href="https://github.com/acme" />
  </.social>
  ```

  The icons come from MJML: `facebook`, `twitter`, `x`, `google`, `pinterest`, `linkedin`,
  `tumblr`, `xing`, `github`, `instagram`, `web`, `snapchat`, `youtube`, `vimeo`, `medium`,
  `soundcloud` and `dribbble`. For anything else, give the URL of an icon with `src`.

  Each icon links to its `href`, such as your company's page on that network. (In `mj-social`,
  some networks, such as `facebook`, `x` and `linkedin`, link to a page that shares the `href`
  instead. For share buttons, write an `mj-social` yourself.)

  ## Attributes

    * `brand_colors` - use each network's own color instead of `muted`. Defaults to `false`.
    * Other attributes are passed to the `mj-social`, such as `align` (which defaults to
      `"center"`) or `icon-size`.

  ## Slots

    * `link` (required) - an icon, with an optional label as its content. Attributes: `name`
      and `href` (required), and `src`.
  """
  @spec social(map()) :: MjmlEEx.Rendered.t()
  attr :brand_colors, :boolean, default: false
  attr :rest, :global, for: "mj-social"

  slot :link, required: true do
    attr :name, :string, required: true
    attr :href, :string, required: true
    attr :src, :string
  end

  def social(assigns) do
    theme = Theme.current()

    defaults = [
      align: "center",
      color: theme.text,
      "font-size": "14px",
      "icon-size": "20px",
      "icon-padding": "6px",
      "border-radius": "16px",
      "inner-padding": "4px 6px",
      padding: "10px 25px"
    ]

    assigns =
      assigns
      |> assign(:attrs, merge_attrs(defaults, assigns.rest))
      |> assign(:icon_color, if(!assigns.brand_colors, do: theme.muted))

    ~MJML"""
    <mj-social :if={@link != []} {@attrs}>
      <mj-social-element
        :for={link <- @link}
        name={profile_network(link.name)}
        href={link.href}
        src={link[:src]}
        alt={link.name}
        background-color={@icon_color}
      >
        {render_slot(link)}
      </mj-social-element>
    </mj-social>
    """
  end

  # For these networks, MJML turns the href into a "share this page" link (such as
  # facebook.com/sharer/sharer.php?u=...). Their -noshare variants, with the same icon and color,
  # link to the href itself.
  @share_networks ~w(facebook twitter x google pinterest linkedin tumblr xing)

  defp profile_network(name) when name in @share_networks, do: name <> "-noshare"
  defp profile_network(name), do: name

  ## Helpers

  # The component's attributes for its MJML tag, with the ones the caller gave on top. The
  # component's come first, in their order, then the caller's other attributes by name, so the
  # MJML is the same from one run to the next.
  defp merge_attrs(defaults, rest) do
    merged = for {name, value} <- defaults, do: {name, Map.get(rest, name, value)}
    merged ++ Enum.sort(Map.drop(rest, Keyword.keys(defaults)))
  end

  # An inline style from a keyword list, without the nil values
  defp style(declarations) do
    for {property, value} <- declarations, value != nil, into: "", do: "#{property}:#{value};"
  end

  defp heading_font(theme), do: theme.heading_font_family || theme.font_family

  # Mixes two colors, weight being the share of the first, such as a light tint of a color
  # on white. Only hex and rgb() colors can be mixed; for others, it returns fallback.
  defp mix(color, other, weight, fallback) do
    with {r1, g1, b1} <- rgb(color), {r2, g2, b2} <- rgb(other) do
      channels = for {a, b} <- [{r1, r2}, {g1, g2}, {b1, b2}], into: <<>>, do: <<round(a * weight + b * (1 - weight))>>
      "#" <> Base.encode16(channels)
    else
      _ -> fallback
    end
  end

  defp rgb("#" <> <<r, g, b>>), do: rgb("#" <> <<r, r, g, g, b, b>>)

  defp rgb("#" <> <<hex::binary-size(6)>>) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, <<r, g, b>>} -> {r, g, b}
      :error -> nil
    end
  end

  defp rgb("rgb(" <> rest) do
    with [values, ""] <- String.split(rest, ")"),
         [r, g, b] <- values |> String.split(",") |> Enum.map(&Integer.parse(String.trim(&1))),
         {r, ""} <- r,
         {g, ""} <- g,
         {b, ""} <- b,
         true <- Enum.all?([r, g, b], &(&1 in 0..255)) do
      {r, g, b}
    else
      _ -> nil
    end
  end

  defp rgb(_color), do: nil
end
