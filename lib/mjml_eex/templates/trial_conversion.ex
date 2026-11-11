defmodule MjmlEEx.Templates.TrialConversion do
  @moduledoc """
  A free trial conversion email, sent as a trial ends: how much time is left, what the user
  has done so far, what the paid plan includes, and a button to upgrade.

  <img src="images/templates/trial_conversion.jpg" width="400" alt="The free trial conversion email">

  ```elixir
  MjmlEEx.Templates.TrialConversion.to_html(
    product_name: "Acme",
    name: "Jane",
    trial_ends: "October 15",
    days_left: 3,
    upgrade_url: "https://acme.com/billing/upgrade",
    plan: "Pro",
    price: "$12 per user, per month",
    usage: [
      %{value: "12", label: "Projects"},
      %{value: "5", label: "Teammates"},
      %{value: "148", label: "Tasks done"}
    ],
    features: ["Unlimited projects", "Advanced reports", "Priority support"],
    contact_url: "https://acme.com/sales"
  )
  ```

  ## Assigns

    * `:product_name` (required) - your product's name, for the header and the text.
    * `:trial_ends` (required) - when the trial ends, such as `"October 15"`.
    * `:upgrade_url` (required) - the URL of your upgrade page.
    * `:days_left` - the number of days left in the trial, shown above the heading.
    * `:name` - the user's name, to greet them with.
    * `:plan` - the plan to upgrade to. Defaults to `"Pro"`.
    * `:price` - the plan's price, such as `"$12 per user, per month"`.
    * `:usage` - what the user has done during the trial, as a list of maps with `:value` and
      `:label` keys. Three fit best.
    * `:features` - what the plan includes, as a list of strings.
    * `:contact_url` - the URL to contact your team with questions.
    * `:preview` - the preview text. Defaults to a sentence about upgrading to `:plan`.
    * `:logo` - the URL of your logo. Without it, the header shows `:product_name`.
    * `:product_url` - the URL the logo links to.
    * `:support_url` - the URL of your help page, linked in the footer.
    * `:unsubscribe_url` - the URL to unsubscribe from these emails, linked in the footer.
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
  attr :trial_ends, :string, required: true
  attr :upgrade_url, :string, required: true
  attr :days_left, :integer, default: nil
  attr :name, :string, default: nil
  attr :plan, :string, default: "Pro"
  attr :price, :string, default: nil
  attr :usage, :list, default: []
  attr :features, :list, default: []
  attr :contact_url, :string, default: nil
  attr :preview, :string, default: nil
  attr :logo, :string, default: nil
  attr :product_url, :string, default: nil
  attr :support_url, :string, default: nil
  attr :unsubscribe_url, :string, default: nil
  attr :address, :string, default: nil
  attr :lang, :string, default: "en"
  attr :dir, :string, default: nil

  def render(assigns) do
    assigns = assign(assigns, :theme, MjmlEEx.Theme.current())

    ~MJML"""
    <.email
      title={"Your #{@product_name} trial ends on #{@trial_ends}"}
      preview={@preview || "Upgrade to #{@plan} to keep everything you've built in #{@product_name}."}
      lang={@lang}
      dir={@dir}
    >
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <.card padding="32px 0">
        <.badge :if={@days_left} variant="warning" padding="0 25px 4px">{days_left(@days_left)}</.badge>
        <.heading>Your {@product_name} trial ends on {@trial_ends}</.heading>
        <.text>
          {if @name, do: "Hi #{@name}, you've", else: "You've"} made a great start. Upgrade to {@plan} before
          your trial ends to keep everything you've built.
        </.text>
        <%= if @usage != [] do %>
          <.text variant="small" font-weight="600" text-transform="uppercase" letter-spacing="0.5px" padding="16px 25px 8px">
            Your trial so far
          </.text>
          <mj-table table-layout="fixed" padding="0 25px 16px">
            <tr>
              <%= for {stat, index} <- Enum.with_index(@usage) do %>
                <td :if={index > 0} style="width: 12px;"></td>
                <td style={stat_style(@theme)}>
                  <div style={"font-size: 28px; line-height: 36px; font-weight: 700; color: #{@theme.heading};"}>
                    {stat.value}
                  </div>
                  <div style={"font-size: 14px; line-height: 20px; color: #{@theme.muted};"}>{stat.label}</div>
                </td>
              <% end %>
            </tr>
          </mj-table>
        <% end %>
        <%= if @features != [] do %>
          <.heading level={3} padding="16px 25px 8px">Everything in {@plan}</.heading>
          <.checklist padding="0 25px 16px">
            <:item :for={feature <- @features}>{feature}</:item>
          </.checklist>
        <% end %>
        <.text :if={@price}><strong>{@plan}</strong> is {@price}.</.text>
        <.button href={@upgrade_url}>Upgrade to {@plan}</.button>
        <%= if @contact_url do %>
          <.divider />
          <.text variant="small">
            Have questions about {@plan}? <.link href={@contact_url}>Talk to our team</.link>.
          </.text>
        <% end %>
      </.card>
      <.footer :if={@address || @support_url || @unsubscribe_url}>
        {@address}
        <:link :if={@support_url} href={@support_url}>Help center</:link>
        <:link :if={@unsubscribe_url} href={@unsubscribe_url}>Unsubscribe</:link>
      </.footer>
    </.email>
    """
  end

  defp days_left(1), do: "1 day left in your trial"
  defp days_left(days), do: "#{days} days left in your trial"

  defp stat_style(theme) do
    "padding: 16px 8px; text-align: center; border-radius: #{theme.button_radius}; " <>
      "background-color: #{theme.subtle};"
  end
end
