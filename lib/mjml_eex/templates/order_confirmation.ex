defmodule MjmlEEx.Templates.OrderConfirmation do
  @moduledoc """
  An order confirmation for an online store: the order's items with their pictures, the
  totals, when it should arrive, and where it's going.

  <img src="images/templates/order_confirmation.jpg" width="400" alt="The order confirmation email">

  ```elixir
  MjmlEEx.Templates.OrderConfirmation.to_html(
    product_name: "Acme",
    name: "Jane",
    order_number: "#1042",
    items: [
      %{name: "Stoneware mug", detail: "Rust", quantity: 2, price: "$38.00", image: "https://acme.com/mug.png"},
      %{name: "Glazed bottle vase", detail: "Sage", quantity: 1, price: "$68.00", image: "https://acme.com/vase.png"}
    ],
    totals: [{"Subtotal", "$106.00"}, {"Shipping", "Free"}, {"Tax", "$8.48"}],
    total: "$114.48",
    delivery_estimate: "October 18 – 20",
    shipping_address: ["Jane Cooper", "100 Main St", "Springfield, IL 62701"],
    payment_method: "Visa ending in 4242",
    order_url: "https://acme.com/orders/1042"
  )
  ```

  Prices and dates are shown as they're given, so format them first, in the user's currency
  and language.

  ## Assigns

    * `:product_name` (required) - your store's name, for the header and the text.
    * `:order_number` (required) - the order's number.
    * `:items` (required) - the items, as a list of maps with `:name` and `:price` keys, and
      optionally `:image` (the URL of a square picture), `:detail` (such as the color or
      size) and `:quantity`.
    * `:total` (required) - the order's total.
    * `:totals` - the rows above the total, such as the subtotal, shipping and tax, as a list
      of `{label, value}` tuples.
    * `:name` - the customer's name, to thank them with.
    * `:order_url` - the URL of the order's page.
    * `:delivery_estimate` - when the order should arrive, such as `"October 18 – 20"`.
    * `:shipping_address` - where the order is going, as a list of lines.
    * `:payment_method` - how the order was paid, such as `"Visa ending in 4242"`.
    * `:logo` - the URL of your logo. Without it, the header shows `:product_name`.
    * `:product_url` - the URL the logo links to.
    * `:support_url` - the URL to contact you with questions about the order.
    * `:address` - your company's address, for the footer.

  To change the text or the layout, copy the template into your app (see
  [Prebuilt templates](prebuilt_templates.md)).
  """

  use MjmlEEx
  import MjmlEEx.CoreComponents

  @doc "Renders the email's MJML. `to_html/1` renders it and compiles it to HTML."
  @spec render(map()) :: MjmlEEx.Rendered.t()
  attr :product_name, :string, required: true
  attr :order_number, :string, required: true
  attr :items, :list, required: true
  attr :total, :string, required: true
  attr :totals, :list, default: []
  attr :name, :string, default: nil
  attr :order_url, :string, default: nil
  attr :delivery_estimate, :string, default: nil
  attr :shipping_address, :list, default: []
  attr :payment_method, :string, default: nil
  attr :logo, :string, default: nil
  attr :product_url, :string, default: nil
  attr :support_url, :string, default: nil
  attr :address, :string, default: nil

  def render(assigns) do
    assigns = assign(assigns, :theme, MjmlEEx.Theme.current())

    ~MJML"""
    <.email
      title={"Order #{@order_number} confirmed"}
      preview={"Thanks for your order! We're getting order #{@order_number} ready."}
    >
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <.card padding="32px 0">
        <.badge variant="success" padding="0 25px 4px">Order confirmed</.badge>
        <.heading>Thanks for your order{if @name, do: ", #{@name}"}!</.heading>
        <.text>
          We've received order <strong>{@order_number}</strong> and we're getting it ready. We'll email you again
          when it ships.
        </.text>
        <.callout :if={@delivery_estimate} variant="neutral" title="Estimated delivery">
          {@delivery_estimate}
        </.callout>
        <.button :if={@order_url} href={@order_url} padding="16px 25px 10px">View your order</.button>
        <.divider />
        <.table rows={@items}>
          <:col :let={item} :if={Enum.any?(@items, & &1[:image])} width="64px">
            <img
              :if={item[:image]}
              src={item.image}
              alt={item.name}
              width="64"
              height="64"
              style={"display: block; width: 64px; height: 64px; border-radius: #{@theme.button_radius};"}
            />
          </:col>
          <:col :let={item}>
            <div style={"font-weight: 600; color: #{@theme.heading};"}>{item.name}</div>
            <div :if={item[:detail]} style={"font-size: 14px; line-height: 20px; color: #{@theme.muted};"}>
              {item.detail}
            </div>
            <div :if={item[:quantity]} style={"font-size: 14px; line-height: 20px; color: #{@theme.muted};"}>
              Qty {item.quantity}
            </div>
          </:col>
          <:col :let={item} align="right" width="25%">{item.price}</:col>
        </.table>
        <.list>
          <:item :for={{label, value} <- @totals} title={label}>{value}</:item>
          <:item title="Total" strong>{@total}</:item>
        </.list>
        <%= if @shipping_address != [] || @payment_method do %>
          <.divider />
          <.list>
            <:item :if={@shipping_address != []} title="Shipping to">
              <%= for {line, index} <- Enum.with_index(@shipping_address) do %>
                <br :if={index > 0} />{line}
              <% end %>
            </:item>
            <:item :if={@payment_method} title="Payment">{@payment_method}</:item>
          </.list>
        <% end %>
        <%= if @support_url do %>
          <.divider />
          <.text variant="small">
            Questions about your order? <.link href={@support_url}>Contact us</.link> and we'll help.
          </.text>
        <% end %>
      </.card>
      <.footer :if={@address}>{@address}</.footer>
    </.email>
    """
  end
end
