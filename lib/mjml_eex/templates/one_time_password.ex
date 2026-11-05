defmodule MjmlEEx.Templates.OneTimePassword do
  @moduledoc """
  A one-time password email: a code to sign in or confirm an action with, and where the
  request came from.

  <img src="images/templates/one_time_password.jpg" width="400" alt="The one-time password email">

  ```elixir
  MjmlEEx.Templates.OneTimePassword.to_html(
    product_name: "Acme",
    code: "482913",
    device: "Chrome on macOS",
    location: "Lisbon, Portugal",
    requested_at: "October 12, 2026 at 9:41 AM UTC"
  )
  ```

  The code is in the email's preview text too, so it shows in the inbox.

  ## Assigns

    * `:product_name` (required) - your product's name, for the header and the text.
    * `:code` (required) - the code.
    * `:expires_in` - how long the code works for. Defaults to `"10 minutes"`.
    * `:device`, `:location` and `:requested_at` - where and when the code was requested.
      The email lists the ones that are given.
    * `:logo` - the URL of your logo. Without it, the header shows `:product_name`.
    * `:product_url` - the URL the logo links to.
    * `:support_url` - the URL of your help page, linked in the footer.
    * `:address` - your company's address, for the footer.

  To change the text or the layout, copy the template into your app (see
  [Prebuilt templates](prebuilt_templates.md)).
  """

  use MjmlEEx
  import MjmlEEx.CoreComponents

  @doc "Renders the email's MJML. `to_html/1` renders it and compiles it to HTML."
  @spec render(map()) :: MjmlEEx.Rendered.t()
  attr :product_name, :string, required: true
  attr :code, :string, required: true
  attr :expires_in, :string, default: "10 minutes"
  attr :device, :string, default: nil
  attr :location, :string, default: nil
  attr :requested_at, :string, default: nil
  attr :logo, :string, default: nil
  attr :product_url, :string, default: nil
  attr :support_url, :string, default: nil
  attr :address, :string, default: nil

  def render(assigns) do
    ~MJML"""
    <.email
      title={"Your #{@product_name} verification code"}
      preview={"Your verification code is #{@code}. It expires in #{@expires_in}."}
    >
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <.card padding="32px 0">
        <.heading align="center">Your verification code</.heading>
        <.text align="center">
          Enter this code in {@product_name} to continue. It expires in {@expires_in}.
        </.text>
        <.code>{@code}</.code>
        <.text variant="small" align="center">
          Never share this code. {@product_name} will never ask you for it.
        </.text>
        <.divider />
        <%= if @device || @location || @requested_at do %>
          <.text variant="small">This code was requested from:</.text>
          <.list font-size="14px" line-height="20px">
            <:item :if={@device} title="Device">{@device}</:item>
            <:item :if={@location} title="Location">{@location}</:item>
            <:item :if={@requested_at} title="Time">{@requested_at}</:item>
          </.list>
        <% end %>
        <.text variant="small">
          If you didn't request this code, you can ignore this email. Someone may have typed your email
          address by mistake.
        </.text>
      </.card>
      <.footer :if={@address || @support_url}>
        {@address}
        <:link :if={@support_url} href={@support_url}>Help center</:link>
      </.footer>
    </.email>
    """
  end
end
