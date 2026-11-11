defmodule MjmlEEx.Templates.FlashSale do
  @moduledoc """
  A flash sale announcement: a bold hero with the offer, a promo code and a button, then a
  grid of products on sale.

  <img src="images/templates/flash_sale.jpg" width="400" alt="The flash sale email">

  ```elixir
  MjmlEEx.Templates.FlashSale.to_html(
    product_name: "Acme",
    headline: "40% off everything",
    description: "Our biggest sale of the season. Two days only.",
    code: "FLASH40",
    ends: "Ends Sunday at midnight",
    shop_url: "https://acme.com/sale",
    background_image: "https://acme.com/images/sale.png",
    products: [
      %{name: "Stoneware mug", price: "$32", sale_price: "$19", image: "https://acme.com/mug.png", url: "https://acme.com/mug"},
      %{name: "Glazed vase", price: "$68", sale_price: "$40", image: "https://acme.com/vase.png", url: "https://acme.com/vase"}
    ],
    unsubscribe_url: "https://acme.com/unsubscribe",
    address: "Acme Inc., 1 Market St, San Francisco"
  )
  ```

  ## Assigns

    * `:product_name` (required) - your store's name, for the header.
    * `:headline` (required) - the offer, such as `"40% off everything"`.
    * `:shop_url` (required) - the URL of the sale.
    * `:unsubscribe_url` (required) - the URL to unsubscribe, linked in the footer.
    * `:address` (required) - your company's postal address, for the footer.
    * `:description` - a sentence under the headline.
    * `:label` - the text above the headline. Defaults to `"Flash sale"`.
    * `:code` - a promo code.
    * `:ends` - when the sale ends, such as `"Ends Sunday at midnight"`.
    * `:cta_label` - the button's label. Defaults to `"Shop the sale"`.
    * `:background_image` - the URL of an image for the hero's background. Without it, the
      hero is in the theme's `heading` color. Either way, its text is in the theme's
      `surface` color, so pick a dark image.
    * `:products` - products on sale, as a list of maps with `:name`, `:price`, `:image` and
      `:url` keys, and optionally `:sale_price`. They're shown two per row, so square images
      fit best.
    * `:products_title` - the heading above the products. Defaults to `"Shop the sale"`.
    * `:terms` - the offer's terms, in small print in the footer.
    * `:preview` - the preview text. Defaults to the headline and `:ends`.
    * `:logo` - the URL of your logo. Without it, the header shows `:product_name`.
    * `:product_url` - the URL the logo links to.
    * `:social` - social links for the footer, as a keyword list of `mj-social` names and
      URLs, such as `[instagram: "https://instagram.com/acme"]`.
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
  attr :shop_url, :string, required: true
  attr :unsubscribe_url, :string, required: true
  attr :address, :string, required: true
  attr :description, :string, default: nil
  attr :label, :string, default: "Flash sale"
  attr :code, :string, default: nil
  attr :ends, :string, default: nil
  attr :cta_label, :string, default: "Shop the sale"
  attr :background_image, :string, default: nil
  attr :products, :list, default: []
  attr :products_title, :string, default: "Shop the sale"
  attr :terms, :string, default: nil
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
    <.email title={@headline} preview={@preview || Enum.join(Enum.reject([@headline, @ends], &is_nil/1), ". ")} lang={@lang} dir={@dir}>
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <.hero variant="dark" background_image={@background_image} padding="56px 0 48px">
        <.badge solid align="center" text-transform="uppercase" letter-spacing="2px" padding="0 25px">
          {@label}
        </.badge>
        <.heading align="center" font-size="56px" line-height="60px" font-weight="800" padding="20px 25px 12px">
          {@headline}
        </.heading>
        <.text :if={@description} variant="lead" align="center">{@description}</.text>
        <mj-text :if={@code} align="center" padding="16px 25px 0">
          <span style={code_style(@theme)}>
            Use code <strong style="font-size: 18px; letter-spacing: 2px;">{@code}</strong>
          </span>
        </mj-text>
        <.button href={@shop_url} align="center" font-size="17px" inner-padding="14px 32px" padding="24px 25px 8px">
          {@cta_label}
        </.button>
        <.text :if={@ends} variant="small" align="center">{@ends}</.text>
      </.hero>
      <mj-wrapper
        :if={@products != []}
        background-color={@theme.surface}
        border-radius={@theme.radius}
        padding="32px 0 24px"
      >
        <mj-section padding="0">
          <mj-column>
            <.heading level={2} align="center" padding="0 25px 8px">{@products_title}</.heading>
          </mj-column>
        </mj-section>
        <mj-section :for={row <- Enum.chunk_every(@products, 2)} padding="0">
          <mj-group>
            <mj-column :for={{product, index} <- Enum.with_index(row)} width="50%" vertical-align="top">
              <mj-image
                src={product.image}
                alt={product.name}
                href={product.url}
                border-radius={@theme.button_radius}
                padding={if index == 0, do: "16px 8px 8px 25px", else: "16px 25px 8px 8px"}
              />
              <mj-text padding={if index == 0, do: "0 8px 0 25px", else: "0 25px 0 8px"}>
                <a href={product.url} style={"font-weight: 600; text-decoration: none; color: #{@theme.heading};"}>
                  {product.name}
                </a><br />
                <%= if product[:sale_price] do %>
                  <s style={"color: #{@theme.muted};"}>{product.price}</s>&nbsp;
                  <strong style={"color: #{@theme.danger};"}>{product.sale_price}</strong>
                <% else %>
                  {product.price}
                <% end %>
              </mj-text>
            </mj-column>
          </mj-group>
        </mj-section>
        <mj-section padding="16px 0 0">
          <mj-column>
            <.button href={@shop_url} variant="outline" align="center" padding="8px 25px 0">See everything on sale</.button>
          </mj-column>
        </mj-section>
      </mj-wrapper>
      <.footer>
        <span :if={@terms}>{@terms}<br /><br /></span>
        {@address}
        <:link href={@unsubscribe_url}>Unsubscribe</:link>
        <:social :for={{name, href} <- pairs!(@social, :social)} name={to_string(name)} href={href} />
      </.footer>
    </.email>
    """
  end

  defp code_style(theme) do
    "display: inline-block; padding: 10px 20px; border: 2px dashed #{theme.surface}; " <>
      "border-radius: #{theme.button_radius}; font-size: 15px; line-height: 24px; color: #{theme.surface};"
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
