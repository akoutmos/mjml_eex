defmodule MjmlEEx.Templates.ProductLaunch do
  @moduledoc """
  A product launch announcement: a headline and a button, a large product image, a grid of
  features and a customer quote.

  <img src="images/templates/product_launch.jpg" width="400" alt="The product launch email">

  ```elixir
  MjmlEEx.Templates.ProductLaunch.to_html(
    product_name: "Acme",
    headline: "Introducing Acme Insights",
    description: "See how your team works, in real time, with dashboards that build themselves.",
    cta_url: "https://acme.com/insights",
    image: "https://acme.com/images/insights.png",
    features: [
      %{title: "Live dashboards", description: "Every chart updates as work happens."},
      %{title: "Smart alerts", description: "Hear about changes before they become problems."},
      %{title: "Shareable reports", description: "Send a link to anyone, no account needed."}
    ],
    quote: %{text: "Insights replaced three tools for us.", author: "Sam Lee", role: "COO, Globex"},
    unsubscribe_url: "https://acme.com/unsubscribe",
    address: "Acme Inc., 1 Market St, San Francisco"
  )
  ```

  ## Assigns

    * `:product_name` (required) - your product's name, for the header.
    * `:headline` (required) - the headline.
    * `:description` (required) - a sentence or two under the headline.
    * `:cta_url` (required) - the URL the buttons link to.
    * `:unsubscribe_url` (required) - the URL to unsubscribe, linked in the footer.
    * `:address` (required) - your company's postal address, for the footer.
    * `:cta_label` - the buttons' label. Defaults to `"Try it now"`.
    * `:label` - the badge above the headline. Defaults to `"New"`.
    * `:image` - the URL of a product image or screenshot, under the headline. 5:3 fits
      best.
    * `:image_alt` - the image's alternative text. Defaults to the headline.
    * `:features` - the features, as a list of maps with `:title` and `:description` keys.
      They're shown in three columns when there are three, six or nine of them, in one when
      there's one, and in two otherwise.
    * `:features_title` - the heading above the features. Defaults to `"What's new"`.
    * `:quote` - a customer quote, as a map with `:text` and `:author` keys, and optionally
      `:role`.
    * `:learn_more_url` - the URL of a page with more details, such as a blog post, linked
      under the first button.
    * `:preview` - the preview text. Defaults to `:description`.
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
  attr :headline, :string, required: true
  attr :description, :string, required: true
  attr :cta_url, :string, required: true
  attr :unsubscribe_url, :string, required: true
  attr :address, :string, required: true
  attr :cta_label, :string, default: "Try it now"
  attr :label, :string, default: "New"
  attr :image, :string, default: nil
  attr :image_alt, :string, default: nil
  attr :features, :list, default: []
  attr :features_title, :string, default: "What's new"
  attr :quote, :map, default: nil
  attr :learn_more_url, :string, default: nil
  attr :preview, :string, default: nil
  attr :logo, :string, default: nil
  attr :product_url, :string, default: nil
  attr :social, :list, default: []
  attr :lang, :string, default: "en"
  attr :dir, :string, default: "auto", values: ~w(ltr rtl auto)

  def render(assigns) do
    require_text!(assigns, [:unsubscribe_url, :address])
    {per_row, width} = feature_columns(length(assigns.features))

    assigns =
      assigns
      |> assign(:theme, MjmlEEx.Theme.current())
      |> assign(:feature_rows, Enum.chunk_every(assigns.features, per_row))
      |> assign(:feature_width, width)

    ~MJML"""
    <.email title={@headline} preview={@preview || @description} lang={@lang} dir={@dir}>
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <mj-wrapper background-color={@theme.surface} border-radius={@theme.radius} padding="40px 0 32px">
        <mj-section padding="0">
          <mj-column>
            <.badge align="center" text-transform="uppercase" letter-spacing="0.5px" padding="0 25px 16px">
              {@label}
            </.badge>
            <.heading align="center" font-size="36px" line-height="44px" padding="0 25px 16px">{@headline}</.heading>
            <.text variant="lead" align="center" padding="0 40px">{@description}</.text>
            <.button href={@cta_url} align="center" padding="24px 25px 8px">{@cta_label}</.button>
            <.text :if={@learn_more_url} variant="small" align="center">
              <.link href={@learn_more_url}>Read the announcement</.link>
            </.text>
          </mj-column>
        </mj-section>
        <mj-section :if={@image} padding="16px 0 0">
          <mj-column>
            <mj-image
              src={@image}
              alt={@image_alt || @headline}
              href={@cta_url}
              border-radius={@theme.radius}
              padding="0 25px"
            />
          </mj-column>
        </mj-section>
        <mj-section :if={@features != []} padding="16px 0 0">
          <mj-column>
            <.divider padding="16px 25px 24px" />
            <.heading level={2} align="center" padding="0 25px 8px">{@features_title}</.heading>
          </mj-column>
        </mj-section>
        <mj-section :for={row <- @feature_rows} padding="0">
          <mj-column :for={feature <- row} width={@feature_width} vertical-align="top">
            <mj-text padding="16px 25px 0">
              <div style={accent_style(@theme)}></div>
              <div style={"font-size: 17px; line-height: 24px; font-weight: 600; color: #{@theme.heading};"}>
                {feature.title}
              </div>
              <div style={"padding-top: 4px; font-size: 15px; line-height: 22px; color: #{@theme.muted};"}>
                {feature.description}
              </div>
            </mj-text>
          </mj-column>
        </mj-section>
        <mj-section padding="16px 0 0">
          <mj-column>
            <.blockquote :if={@quote} author={@quote.author} role={@quote[:role]} padding="16px 25px">
              {@quote.text}
            </.blockquote>
            <.button href={@cta_url} align="center" padding="16px 25px 0">{@cta_label}</.button>
          </mj-column>
        </mj-section>
      </mj-wrapper>
      <.footer>
        {@address}
        <:link href={@unsubscribe_url}>Unsubscribe</:link>
        <:social :for={{name, href} <- pairs!(@social, :social)} name={to_string(name)} href={href} />
      </.footer>
    </.email>
    """
  end

  defp feature_columns(count) when count in [3, 6, 9], do: {3, nil}
  defp feature_columns(count) when count > 1, do: {2, "50%"}
  defp feature_columns(_count), do: {1, nil}

  defp accent_style(theme) do
    "width: 24px; height: 4px; margin-bottom: 12px; border-radius: 2px; font-size: 0; line-height: 0; " <>
      "background-color: #{theme.primary};"
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
