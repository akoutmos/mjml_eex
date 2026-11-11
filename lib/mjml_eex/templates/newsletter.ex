defmodule MjmlEEx.Templates.Newsletter do
  @moduledoc """
  A newsletter: an introduction, a featured story with a large image, more stories with
  thumbnails, and a list of quick links.

  <img src="images/templates/newsletter.jpg" width="400" alt="The newsletter email">

  ```elixir
  MjmlEEx.Templates.Newsletter.to_html(
    product_name: "Acme",
    title: "The Acme Dispatch",
    issue: "Issue 42 · October 2026",
    intro: "This month: what we learned shipping our biggest release yet.",
    featured: %{
      label: "Product",
      title: "Inside the redesign of Acme Insights",
      summary: "How we rebuilt our analytics from the ground up.",
      image: "https://acme.com/blog/insights.png",
      url: "https://acme.com/blog/insights"
    },
    stories: [
      %{title: "Five reports every team should automate", summary: "...", url: "https://acme.com/blog/reports"}
    ],
    links: [%{title: "Acme 4.2 release notes", url: "https://acme.com/changelog", source: "Changelog"}],
    unsubscribe_url: "https://acme.com/unsubscribe",
    address: "Acme Inc., 1 Market St, San Francisco"
  )
  ```

  ## Assigns

    * `:product_name` (required) - your product's name, for the header.
    * `:title` (required) - the newsletter's name.
    * `:unsubscribe_url` (required) - the URL to unsubscribe, linked in the footer.
    * `:address` (required) - your company's postal address, for the footer.
    * `:issue` - the issue's number or date, shown above the title.
    * `:intro` - a paragraph to start the issue with.
    * `:sign_off` - who the introduction is from, such as `"Maya, editor of the Dispatch"`.
    * `:featured` - the featured story, as a map with `:title`, `:summary` and `:url` keys,
      and optionally `:image` (the URL of an image, 2:1 fits best) and `:label` (a category,
      shown above the title).
    * `:stories` - more stories, as a list of maps with the same keys as `:featured`. Their
      images are thumbnails, 4:3 fits best.
    * `:links` - quick links, as a list of maps with `:title` and `:url` keys, and optionally
      `:source`.
    * `:preview` - the preview text. Defaults to the featured story's title.
    * `:logo` - the URL of your logo. Without it, the header shows `:product_name`.
    * `:product_url` - the URL the logo links to.
    * `:social` - social links for the footer, as a keyword list of `mj-social` names and
      URLs, such as `[linkedin: "https://linkedin.com/company/acme"]`.
    * `:lang` - the language of the email, for screen readers. Defaults to `"en"`, the
      language of the template's text.
    * `:dir` - the direction of the text: `"ltr"`, `"rtl"` or `"auto"` (the default). The
      template's layout stays left to right.

  To change the text or the layout, copy the template into your app (see
  [Prebuilt templates](prebuilt_templates.md)).
  """

  use MjmlEEx
  import MjmlEEx.CoreComponents

  @doc "Renders the email's MJML. `to_html/1` renders it and compiles it to HTML."
  @spec render(map()) :: MjmlEEx.Rendered.t()
  attr :product_name, :string, required: true
  attr :title, :string, required: true
  attr :unsubscribe_url, :string, required: true
  attr :address, :string, required: true
  attr :issue, :string, default: nil
  attr :intro, :string, default: nil
  attr :sign_off, :string, default: nil
  attr :featured, :map, default: nil
  attr :stories, :list, default: []
  attr :links, :list, default: []
  attr :preview, :string, default: nil
  attr :logo, :string, default: nil
  attr :product_url, :string, default: nil
  attr :social, :list, default: []
  attr :lang, :string, default: "en"
  attr :dir, :string, default: "auto", values: ~w(ltr rtl auto)

  def render(assigns) do
    require_text!(assigns, [:unsubscribe_url, :address])
    assigns = assign(assigns, :theme, MjmlEEx.Theme.current())

    ~MJML"""
    <.email title={@title} preview={@preview || (@featured && @featured.title)} lang={@lang} dir={@dir}>
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <mj-wrapper background-color={@theme.surface} border-radius={@theme.radius} padding="32px 0 24px">
        <mj-section padding="0">
          <mj-column>
            <.text :if={@issue} variant="eyebrow" padding="0 25px">{@issue}</.text>
            <.heading font-size="32px" line-height="40px" padding="4px 25px 12px">{@title}</.heading>
            <.text :if={@intro} variant="lead">{@intro}</.text>
            <.text :if={@sign_off} variant="muted">&mdash; {@sign_off}</.text>
          </mj-column>
        </mj-section>
        <mj-section :if={@featured} padding="0">
          <mj-column>
            <.divider padding="16px 25px 24px" />
            <mj-image
              :if={@featured[:image]}
              src={@featured.image}
              alt={@featured.title}
              href={@featured.url}
              border-radius={@theme.button_radius}
              padding="0 25px 16px"
            />
            <.text :if={@featured[:label]} variant="eyebrow" padding="0 25px">{@featured.label}</.text>
            <.heading level={2} padding="4px 25px 8px">
              <a href={@featured.url} style="color: inherit; text-decoration: none;">{@featured.title}</a>
            </.heading>
            <.text>{@featured.summary}</.text>
            <.button href={@featured.url} variant="secondary" padding="8px 25px">Read the story</.button>
          </mj-column>
        </mj-section>
        <mj-section :if={@stories != []} padding="0">
          <mj-column>
            <.divider padding="24px 25px 16px" />
            <.heading level={2} padding="0 25px 4px">More stories</.heading>
          </mj-column>
        </mj-section>
        <.story :for={story <- @stories} story={story} theme={@theme} />
        <mj-section :if={@links != []} padding="0">
          <mj-column>
            <.divider padding="16px 25px" />
            <.heading level={2} padding="0 25px 4px">Quick links</.heading>
            <mj-table padding="0 25px">
              <tr :for={link <- @links}>
                <td style={"padding: 10px 0; border-bottom: 1px solid #{@theme.border};"}>
                  <a href={link.url} style={"font-weight: 600; text-decoration: none; color: #{@theme.heading};"}>
                    {link.title}
                  </a>
                  <div :if={link[:source]} style={"font-size: 14px; line-height: 20px; color: #{@theme.muted};"}>
                    {link.source}
                  </div>
                </td>
              </tr>
            </mj-table>
          </mj-column>
        </mj-section>
      </mj-wrapper>
      <.footer>
        {@address}<br :if={@address} />
        You're receiving this because you subscribed to {@title}.
        <:link href={@unsubscribe_url}>Unsubscribe</:link>
        <:social :for={{name, href} <- pairs!(@social, :social)} name={to_string(name)} href={href} />
      </.footer>
    </.email>
    """
  end

  attr :story, :map, required: true
  attr :theme, :map, required: true

  # A story, with its thumbnail on the left. mj-group keeps them side by side on phones.
  defp story(assigns) do
    ~MJML"""
    <mj-section padding="12px 0">
      <mj-group :if={@story[:image]}>
        <mj-column width="36%" vertical-align="top">
          <mj-image
            src={@story.image}
            alt={@story.title}
            href={@story.url}
            border-radius={@theme.button_radius}
            padding="4px 8px 0 25px"
          />
        </mj-column>
        <mj-column width="64%" vertical-align="top">
          <.story_text story={@story} theme={@theme} padding="0 25px 0 12px" />
        </mj-column>
      </mj-group>
      <mj-column :if={!@story[:image]}>
        <.story_text story={@story} theme={@theme} padding="0 25px" />
      </mj-column>
    </mj-section>
    """
  end

  attr :story, :map, required: true
  attr :theme, :map, required: true
  attr :padding, :string, required: true

  defp story_text(assigns) do
    ~MJML"""
    <.text :if={@story[:label]} variant="eyebrow" padding={@padding}>{@story.label}</.text>
    <.heading level={3} padding={@padding}>
      <a href={@story.url} style="color: inherit; text-decoration: none;">{@story.title}</a>
    </.heading>
    <.text variant="small" padding={@padding} color={@theme.text}>{@story.summary}</.text>
    """
  end

  # Marketing emails need a working unsubscribe link and a postal address, and required attrs
  # still accept nil
  defp require_text!(assigns, keys) do
    for key <- keys, not is_binary(assigns[key]) or String.trim(assigns[key]) == "" do
      raise ArgumentError, "#{inspect(__MODULE__)} requires a non-blank #{inspect(key)}, got: #{inspect(assigns[key])}"
    end
  end

  # A :for with a {_, _} pattern would leave out the elements that don't match it
  defp pairs!(nil, _assign), do: []

  defp pairs!(list, assign) do
    Enum.each(list, fn
      {_, _} ->
        :ok

      element ->
        raise ArgumentError,
              "the #{inspect(assign)} assign of #{inspect(__MODULE__)} must be a list of 2-element tuples, such as " <>
                "[x: \"https://x.com/acme\"], got: #{inspect(element)}"
    end)

    list
  end
end
