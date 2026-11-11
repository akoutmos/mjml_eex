defmodule MjmlEEx.Templates.MagicLink do
  @moduledoc """
  A magic link sign-in email: a button that signs the user in, and where the link was
  requested from. Passwordless sign-in, such as the one `mix phx.gen.auth` generates, sends
  one of these.

  <img src="images/templates/magic_link.jpg" width="400" alt="The magic link email">

  ```elixir
  MjmlEEx.Templates.MagicLink.to_html(
    product_name: "Acme",
    email: "jane@example.com",
    sign_in_url: "https://acme.com/users/log-in/SFMyNTY",
    device: "Safari on iPhone",
    location: "Toronto, Canada"
  )
  ```

  ## Assigns

    * `:product_name` (required) - your product's name, for the header and the text.
    * `:sign_in_url` (required) - the URL that signs the user in.
    * `:email` - the address the user is signing in with, shown in the text.
    * `:expires_in` - how long the link works for. Defaults to `"15 minutes"`.
    * `:device`, `:location` and `:requested_at` - where and when the link was requested.
      The email lists the ones that are given.
    * `:preview` - the preview text. Defaults to a sentence about signing in.
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

  @doc "Renders the email's MJML. `to_html/1` renders it and compiles it to HTML."
  @spec render(map()) :: MjmlEEx.Rendered.t()
  attr :product_name, :string, required: true
  attr :sign_in_url, :string, required: true
  attr :email, :string, default: nil
  attr :expires_in, :string, default: "15 minutes"
  attr :device, :string, default: nil
  attr :location, :string, default: nil
  attr :requested_at, :string, default: nil
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
      title={"Sign in to #{@product_name}"}
      preview={@preview || "Here's your link to sign in to #{@product_name}. It expires in #{@expires_in}."}
      lang={@lang}
      dir={@dir}
    >
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <.card padding="32px 0">
        <.heading>Sign in to {@product_name}</.heading>
        <.text :if={@email}>
          Click the button below to sign in as <strong>{@email}</strong>. This link expires in {@expires_in}.
        </.text>
        <.text :if={!@email}>Click the button below to sign in. This link expires in {@expires_in}.</.text>
        <.button href={@sign_in_url}>Sign in to {@product_name}</.button>
        <%= if @device || @location || @requested_at do %>
          <.divider />
          <.text variant="small">This link was requested from:</.text>
          <.list font-size="14px" line-height="20px">
            <:item :if={@device} title="Device">{@device}</:item>
            <:item :if={@location} title="Location">{@location}</:item>
            <:item :if={@requested_at} title="Time">{@requested_at}</:item>
          </.list>
        <% end %>
        <.text variant="small">
          If you didn't request this link, you can ignore this email. Someone may have typed your email address
          by mistake.
        </.text>
        <.divider />
        <.text variant="small">
          If the button doesn't work, copy this link into your browser:<br />
          <.link href={@sign_in_url}><span style="word-break: break-all;">{@sign_in_url}</span></.link>
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
