defmodule MjmlEEx.Templates.ForgotPassword do
  @moduledoc """
  A password reset email, with a button that links to your reset page.

  <img src="images/templates/forgot_password.jpg" width="400" alt="The forgot password email">

  ```elixir
  MjmlEEx.Templates.ForgotPassword.to_html(
    product_name: "Acme",
    name: "Jane",
    reset_url: "https://acme.com/reset-password/SFMyNTY",
    support_url: "https://acme.com/help"
  )
  ```

  ## Assigns

    * `:product_name` (required) - your product's name, for the header and the text.
    * `:reset_url` (required) - the URL of the page where the user chooses a new password.
    * `:name` - the user's name, to greet them with.
    * `:expires_in` - how long the link works for. Defaults to `"1 hour"`.
    * `:preview` - the preview text. Defaults to a sentence about choosing a new password.
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
  attr :reset_url, :string, required: true
  attr :name, :string, default: nil
  attr :expires_in, :string, default: "1 hour"
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
      title={"Reset your #{@product_name} password"}
      preview={@preview || "Choose a new password for your #{@product_name} account. This link expires in #{@expires_in}."}
      lang={@lang}
      dir={@dir}
    >
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <.card>
        <.heading>Reset your password</.heading>
        <.text :if={@name}>Hi {@name},</.text>
        <.text>
          We received a request to reset the password for your {@product_name} account. Click the button below
          to choose a new one. This link expires in {@expires_in}.
        </.text>
        <.button href={@reset_url}>Reset password</.button>
        <.callout variant="neutral" title="Didn't ask to reset your password?">
          You can ignore this email. Your password won't change unless you choose a new one.
        </.callout>
        <.divider />
        <.text variant="small">
          If the button doesn't work, copy this link into your browser:<br />
          <.link href={@reset_url}><span style="word-break: break-all;">{@reset_url}</span></.link>
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
