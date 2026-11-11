defmodule MjmlEEx.Templates.SecurityAlert do
  @moduledoc """
  A security alert about a change to the user's account, such as a new sign-in or a changed
  password, with where it came from and a button to secure the account.

  <img src="images/templates/security_alert.jpg" width="400" alt="The security alert email">

  ```elixir
  MjmlEEx.Templates.SecurityAlert.to_html(
    product_name: "Acme",
    event: :new_sign_in,
    device: "Firefox on Windows",
    location: "Berlin, Germany",
    ip_address: "203.0.113.42",
    occurred_at: "October 12, 2026 at 9:41 AM UTC",
    secure_url: "https://acme.com/account/security"
  )
  ```

  ## Assigns

    * `:product_name` (required) - your product's name, for the header and the text.
    * `:secure_url` (required) - the URL of the page to secure the account on, such as one to
      change the password and sign out other devices.
    * `:event` - what happened: `:new_sign_in`, `:password_changed`, `:email_changed` (send
      this one to the previous address) or `:two_factor_disabled`. Defaults to
      `:new_sign_in`.
    * `:name` - the user's name, to greet them with.
    * `:device`, `:location`, `:ip_address` and `:occurred_at` - where and when it happened.
      The email lists the ones that are given.
    * `:preview` - the preview text. Defaults to `:description`.
    * `:logo` - the URL of your logo. Without it, the header shows `:product_name`.
    * `:product_url` - the URL the logo links to.
    * `:support_url` - the URL of your help page, linked in the footer.
    * `:address` - your company's address, for the footer.
    * `:lang` - the language of the email, for screen readers. Defaults to `"en"`, the
      language of the template's text.
    * `:dir` - the direction of the text, `"ltr"` or `"rtl"`.

  To change the text or the layout, copy the template into your app (see
  [Prebuilt templates](prebuilt_templates.md)).
  """

  use MjmlEEx
  import MjmlEEx.CoreComponents

  @events [:new_sign_in, :password_changed, :email_changed, :two_factor_disabled]

  @doc "Renders the email's MJML. `to_html/1` renders it and compiles it to HTML."
  @spec render(map()) :: MjmlEEx.Rendered.t()
  attr :product_name, :string, required: true
  attr :secure_url, :string, required: true
  attr :event, :atom, default: :new_sign_in, values: @events
  attr :name, :string, default: nil
  attr :device, :string, default: nil
  attr :location, :string, default: nil
  attr :ip_address, :string, default: nil
  attr :occurred_at, :string, default: nil
  attr :preview, :string, default: nil
  attr :logo, :string, default: nil
  attr :product_url, :string, default: nil
  attr :support_url, :string, default: nil
  attr :address, :string, default: nil
  attr :lang, :string, default: "en"
  attr :dir, :string, default: nil

  def render(assigns) do
    {title, description} = event_text(assigns.event, assigns.product_name)

    assigns =
      assigns
      |> assign(:title, title)
      |> assign(:description, description)
      |> assign(:details?, Enum.any?([:device, :location, :ip_address, :occurred_at], &assigns[&1]))

    ~MJML"""
    <.email title={@title} preview={@preview || @description} lang={@lang} dir={@dir}>
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <.card padding="32px 0">
        <.badge variant="warning" padding="0 25px 4px">Security alert</.badge>
        <.heading>{@title}</.heading>
        <.text :if={@name}>Hi {@name},</.text>
        <.text>{@description}</.text>
        <.list :if={@details?}>
          <:item :if={@device} title="Device">{@device}</:item>
          <:item :if={@location} title="Location">{@location}</:item>
          <:item :if={@ip_address} title="IP address">{@ip_address}</:item>
          <:item :if={@occurred_at} title="Time">{@occurred_at}</:item>
        </.list>
        <.text>If this was you, you don't need to do anything.</.text>
        <.callout variant="danger" title="Wasn't you?">
          Someone else may have access to your account. Secure it right away.
        </.callout>
        <.button href={@secure_url} variant="danger" padding="16px 25px 10px">Secure your account</.button>
      </.card>
      <.footer :if={@address || @support_url}>
        {@address}
        <:link :if={@support_url} href={@support_url}>Help center</:link>
      </.footer>
    </.email>
    """
  end

  defp event_text(:new_sign_in, product),
    do: {"New sign-in to your account", "Your #{product} account was just signed in to from a new device."}

  defp event_text(:password_changed, product),
    do: {"Your password was changed", "The password for your #{product} account was just changed."}

  defp event_text(:email_changed, product),
    do:
      {"Your email address was changed",
       "The email address for your #{product} account was just changed. We're letting you know at your previous address."}

  defp event_text(:two_factor_disabled, product),
    do:
      {"Two-factor authentication was turned off",
       "Two-factor authentication was just turned off for your #{product} account."}
end
