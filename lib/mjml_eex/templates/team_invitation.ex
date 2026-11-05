defmodule MjmlEEx.Templates.TeamInvitation do
  @moduledoc """
  An invitation to join a team: who sent it, their note, and a button to accept it.

  <img src="images/templates/team_invitation.jpg" width="400" alt="The team invitation email">

  ```elixir
  MjmlEEx.Templates.TeamInvitation.to_html(
    product_name: "Acme",
    inviter_name: "Maya Patel",
    team_name: "Globex",
    accept_url: "https://acme.com/invitations/SFMyNTY",
    message: "We're planning Q4 in Acme now. Join us!",
    role: "Editor"
  )
  ```

  ## Assigns

    * `:product_name` (required) - your product's name, for the header and the text.
    * `:inviter_name` (required) - who sent the invitation.
    * `:team_name` (required) - the team, workspace or organization the invitation is to.
    * `:accept_url` (required) - the URL that accepts the invitation.
    * `:inviter_photo` - the URL of a square photo of the inviter. Without it, their
      initials are shown.
    * `:message` - a note from the inviter.
    * `:role` - the role the user will have, such as `"Editor"`.
    * `:expires_in` - how long the invitation lasts. Defaults to `"7 days"`.
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
  attr :inviter_name, :string, required: true
  attr :team_name, :string, required: true
  attr :accept_url, :string, required: true
  attr :inviter_photo, :string, default: nil
  attr :message, :string, default: nil
  attr :role, :string, default: nil
  attr :expires_in, :string, default: "7 days"
  attr :logo, :string, default: nil
  attr :product_url, :string, default: nil
  attr :support_url, :string, default: nil
  attr :address, :string, default: nil

  def render(assigns) do
    ~MJML"""
    <.email
      title={"#{@inviter_name} invited you to join #{@team_name} on #{@product_name}"}
      preview={@message || "Join #{@team_name} on #{@product_name}."}
    >
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <.card padding="40px 0 32px">
        <mj-text align="center" padding="0 25px 8px">
          <.avatar name={@inviter_name} src={@inviter_photo} size={64} />
        </mj-text>
        <.heading align="center" font-size="24px" line-height="32px">
          {@inviter_name} invited you to join {@team_name} on {@product_name}
        </.heading>
        <.text :if={@role} variant="muted" align="center">You'll join as <strong>{@role}</strong>.</.text>
        <.blockquote :if={@message} author={@inviter_name} padding="16px 25px 8px">{@message}</.blockquote>
        <.button href={@accept_url} align="center" padding="16px 25px">Accept invitation</.button>
        <.text variant="small" align="center">
          This invitation expires in {@expires_in}. If you weren't expecting it, you can ignore this email.
        </.text>
        <.divider />
        <.text variant="small">
          If the button doesn't work, copy this link into your browser:<br />
          <.link href={@accept_url}><span style="word-break: break-all;">{@accept_url}</span></.link>
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
