defmodule MjmlEEx.Templates.Invoice do
  @moduledoc """
  An invoice: the amount due and when, a button to pay it, and the invoice's details, line
  items and totals.

  <img src="images/templates/invoice.jpg" width="400" alt="The invoice email">

  ```elixir
  MjmlEEx.Templates.Invoice.to_html(
    product_name: "Acme",
    invoice_number: "INV-2026-0042",
    amount_due: "$1,286.40",
    due_date: "October 31, 2026",
    issued_on: "October 1, 2026",
    billed_to: ["Jane Cooper", "Globex Corporation", "100 Main St, Springfield, IL 62701"],
    items: [
      %{description: "Pro plan", detail: "Oct 1 – Oct 31, 2026", quantity: 10, amount: "$1,080.00"},
      %{description: "Extra storage (500 GB)", quantity: 1, amount: "$120.00"}
    ],
    totals: [{"Subtotal", "$1,200.00"}, {"Tax (7.2%)", "$86.40"}],
    pay_url: "https://acme.com/invoices/INV-2026-0042/pay",
    pdf_url: "https://acme.com/invoices/INV-2026-0042.pdf"
  )
  ```

  Amounts and dates are shown as they're given, so format them first, in the user's currency
  and language.

  ## Assigns

    * `:product_name` (required) - your company's or product's name, for the header and the
      text.
    * `:invoice_number` (required) - the invoice's number.
    * `:amount_due` (required) - the amount to pay.
    * `:due_date` (required) - when it's due.
    * `:items` (required) - the line items, as a list of maps with `:description` and `:amount`
      keys, and optionally `:detail` (shown under the description) and `:quantity`.
    * `:totals` - the rows above the amount due, such as the subtotal and the tax, as a list of
      `{label, value}` tuples.
    * `:issued_on` - when the invoice was issued.
    * `:billed_to` - who the invoice is for, as a list of lines.
    * `:pay_url` - the URL of the page to pay the invoice on.
    * `:pdf_url` - the URL to download the invoice from.
    * `:preview` - the preview text. Defaults to the amount due and the due date.
    * `:logo` - the URL of your logo. Without it, the header shows `:product_name`.
    * `:product_url` - the URL the logo links to.
    * `:support_url` - the URL to contact you with questions about the invoice.
    * `:address` - your company's address, for the footer.
    * `:lang` - the language of the email, for screen readers. Defaults to `"en"`, the
      language of the template's text.
    * `:dir` - the direction of the text, `"ltr"` or `"rtl"`.

  To change the text or the layout, copy the template into your app (see
  [Prebuilt templates](prebuilt_templates.md)).
  """

  use MjmlEEx
  import MjmlEEx.CoreComponents

  @doc "Renders the email's MJML. `to_html/1` renders it and compiles it to HTML."
  @spec render(map()) :: MjmlEEx.Rendered.t()
  attr :product_name, :string, required: true
  attr :invoice_number, :string, required: true
  attr :amount_due, :string, required: true
  attr :due_date, :string, required: true
  attr :items, :list, required: true
  attr :totals, :list, default: []
  attr :issued_on, :string, default: nil
  attr :billed_to, :list, default: []
  attr :pay_url, :string, default: nil
  attr :pdf_url, :string, default: nil
  attr :preview, :string, default: nil
  attr :logo, :string, default: nil
  attr :product_url, :string, default: nil
  attr :support_url, :string, default: nil
  attr :address, :string, default: nil
  attr :lang, :string, default: "en"
  attr :dir, :string, default: nil

  def render(assigns) do
    ~MJML"""
    <.email
      title={"Invoice #{@invoice_number} from #{@product_name}"}
      preview={@preview || "Your invoice for #{@amount_due} is due #{@due_date}."}
      lang={@lang}
      dir={@dir}
    >
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <.card padding="32px 0">
        <.text variant="muted" padding="0 25px">Invoice from {@product_name}</.text>
        <.heading font-size="40px" line-height="48px" padding="4px 25px">{@amount_due}</.heading>
        <.text variant="muted" padding="0 25px 16px">Due {@due_date}</.text>
        <.button :if={@pay_url} href={@pay_url}>Pay this invoice</.button>
        <.text :if={@pdf_url} variant="small">
          <.link href={@pdf_url}>Download the invoice (PDF)</.link>
        </.text>
        <.divider />
        <.list>
          <:item title="Invoice number">{@invoice_number}</:item>
          <:item :if={@issued_on} title="Issued">{@issued_on}</:item>
          <:item title="Due">{@due_date}</:item>
          <:item :if={@billed_to != []} title="Billed to">
            <%= for {line, index} <- Enum.with_index(@billed_to) do %>
              <br :if={index > 0} />{line}
            <% end %>
          </:item>
        </.list>
        <.divider />
        <.table rows={@items}>
          <:col :let={item} label="Description">
            {item.description}
            <div :if={item[:detail]} style="font-size: 14px; line-height: 20px; opacity: 0.75;">{item.detail}</div>
          </:col>
          <:col :let={item} :if={Enum.any?(@items, & &1[:quantity])} label="Qty" align="center" width="12%">
            {item[:quantity]}
          </:col>
          <:col :let={item} label="Amount" align="right" width="28%">{item.amount}</:col>
        </.table>
        <.list>
          <:item :for={{label, value} <- @totals} title={label}>{value}</:item>
          <:item title="Amount due" strong>{@amount_due}</:item>
        </.list>
        <%= if @support_url do %>
          <.divider />
          <.text variant="small">
            Questions about this invoice? <.link href={@support_url}>Contact us</.link> and we'll help.
          </.text>
        <% end %>
      </.card>
      <.footer :if={@address}>{@address}</.footer>
    </.email>
    """
  end
end
