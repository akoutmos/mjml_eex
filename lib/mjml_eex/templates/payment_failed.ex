defmodule MjmlEEx.Templates.PaymentFailed do
  @moduledoc """
  A failed payment notice: what couldn't be charged and why, when you'll try again, and a
  button to update the payment details.

  <img src="images/templates/payment_failed.jpg" width="400" alt="The payment failed email">

  ```elixir
  MjmlEEx.Templates.PaymentFailed.to_html(
    product_name: "Acme",
    name: "Jane",
    amount: "$120.00",
    payment_method: "Visa ending in 4242",
    plan: "Pro",
    reason: "Your card was declined.",
    retry_on: "October 15, 2026",
    pay_by: "October 22, 2026",
    update_url: "https://acme.com/billing/payment-method"
  )
  ```

  ## Assigns

    * `:product_name` (required) - your product's name, for the header and the text.
    * `:amount` (required) - the amount that couldn't be charged.
    * `:update_url` (required) - the URL of the page to update the payment details on.
    * `:name` - the user's name, to greet them with.
    * `:payment_method` - what was charged, such as `"Visa ending in 4242"`.
    * `:plan` - the subscription's plan, such as `"Pro"`.
    * `:reason` - why the payment failed, such as `"Your card was declined."`.
    * `:retry_on` - when you'll try to charge the payment method again.
    * `:pay_by` - the date to update the payment details by, to keep the subscription.
    * `:invoice_url` - the URL of the unpaid invoice.
    * `:logo` - the URL of your logo. Without it, the header shows `:product_name`.
    * `:product_url` - the URL the logo links to.
    * `:support_url` - the URL to contact you with questions about billing.
    * `:address` - your company's address, for the footer.

  To change the text or the layout, copy the template into your app (see
  [Prebuilt templates](prebuilt_templates.md)).
  """

  use MjmlEEx
  import MjmlEEx.CoreComponents

  @doc "Renders the email's MJML. `to_html/1` renders it and compiles it to HTML."
  @spec render(map()) :: MjmlEEx.Rendered.t()
  attr :product_name, :string, required: true
  attr :amount, :string, required: true
  attr :update_url, :string, required: true
  attr :name, :string, default: nil
  attr :payment_method, :string, default: nil
  attr :plan, :string, default: nil
  attr :reason, :string, default: nil
  attr :retry_on, :string, default: nil
  attr :pay_by, :string, default: nil
  attr :invoice_url, :string, default: nil
  attr :logo, :string, default: nil
  attr :product_url, :string, default: nil
  attr :support_url, :string, default: nil
  attr :address, :string, default: nil

  def render(assigns) do
    assigns =
      assign(assigns, :subscription, Enum.join(Enum.reject([assigns.product_name, assigns.plan], &is_nil/1), " "))

    ~MJML"""
    <.email
      title="Your payment didn't go through"
      preview={"We couldn't process your payment of #{@amount}. Update your payment details to keep your subscription."}
    >
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <.card padding="32px 0">
        <.badge variant="danger" padding="0 25px 4px">Payment failed</.badge>
        <.heading>We couldn't process your payment</.heading>
        <.text :if={@name}>Hi {@name},</.text>
        <.text>
          We tried to charge {@amount} <span :if={@payment_method}>to your {@payment_method}</span> for your
          {@subscription} subscription, but the payment didn't go through.
        </.text>
        <.list>
          <:item title="Amount">{@amount}</:item>
          <:item :if={@payment_method} title="Payment method">{@payment_method}</:item>
          <:item :if={@reason} title="Reason">{@reason}</:item>
          <:item :if={@retry_on} title="Next attempt">{@retry_on}</:item>
        </.list>
        <.callout :if={@pay_by} variant="warning" title={"Please update your payment details by #{@pay_by}"}>
          This keeps your {@subscription} subscription active.
        </.callout>
        <.button href={@update_url} padding="16px 25px 10px">Update payment method</.button>
        <.text :if={@invoice_url} variant="small"><.link href={@invoice_url}>View the invoice</.link></.text>
        <%= if @support_url do %>
          <.divider />
          <.text variant="small">
            Questions about your bill? <.link href={@support_url}>Contact us</.link> and we'll help.
          </.text>
        <% end %>
      </.card>
      <.footer :if={@address}>{@address}</.footer>
    </.email>
    """
  end
end
