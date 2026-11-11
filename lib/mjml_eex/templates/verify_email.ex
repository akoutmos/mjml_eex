defmodule MjmlEEx.Templates.VerifyEmail do
  @moduledoc """
  An email address confirmation, sent when someone signs up, with a button that confirms
  their address.

  <img src="images/templates/verify_email.jpg" width="400" alt="The email confirmation email">

  ```elixir
  MjmlEEx.Templates.VerifyEmail.to_html(
    product_name: "Acme",
    name: "Jane",
    email: "jane@example.com",
    verify_url: "https://acme.com/confirm/SFMyNTY"
  )
  ```

  ## Assigns

    * `:product_name` (required) - your product's name, for the header and the text.
    * `:verify_url` (required) - the URL that confirms the address.
    * `:name` - the user's name, to greet them with.
    * `:email` - the address being confirmed, shown in the text.
    * `:expires_in` - how long the link works for. Defaults to `"24 hours"`.
    * `:preview` - the preview text. Defaults to a sentence about confirming the email address.
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
  attr :verify_url, :string, required: true
  attr :name, :string, default: nil
  attr :email, :string, default: nil
  attr :expires_in, :string, default: "24 hours"
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
      title={"Confirm your email for #{@product_name}"}
      preview={@preview || "Confirm your email address to finish setting up your #{@product_name} account."}
      lang={@lang}
      dir={@dir}
    >
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <.card padding="32px 0">
        <.heading>{if @name, do: "Welcome, #{@name}!", else: "Welcome to #{@product_name}!"}</.heading>
        <.text variant="lead">
          Thanks for signing up. Confirm your email address to finish setting up your account.
        </.text>
        <.text :if={@email}>
          Click the button below to confirm that <strong>{@email}</strong> is your email address.
        </.text>
        <.text :if={!@email}>Click the button below to confirm your email address.</.text>
        <.button href={@verify_url}>Confirm email address</.button>
        <.text variant="small">
          This link expires in {@expires_in}. If you didn't sign up for {@product_name}, you can ignore this
          email and no account will be created.
        </.text>
        <.divider />
        <.text variant="small">
          If the button doesn't work, copy this link into your browser:<br />
          <.link href={@verify_url}><span style="word-break: break-all;">{@verify_url}</span></.link>
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
