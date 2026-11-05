defmodule MjmlEEx.Templates.Welcome do
  @moduledoc """
  A welcome email for new users: a greeting on a banner in the theme's `primary` color, the
  first steps to take, and where to get help.

  <img src="images/templates/welcome.jpg" width="400" alt="The welcome email">

  ```elixir
  MjmlEEx.Templates.Welcome.to_html(
    product_name: "Acme",
    name: "Jane",
    cta_url: "https://acme.com/dashboard",
    steps: [
      %{title: "Create a project", description: "Projects keep your team's work in one place."},
      %{title: "Invite your team", description: "Plan together and see what's next.", url: "https://acme.com/team", action: "Invite people"}
    ],
    docs_url: "https://acme.com/docs",
    support_url: "https://acme.com/help",
    sign_off: "Maya Patel, CEO of Acme"
  )
  ```

  ## Assigns

    * `:product_name` (required) - your product's name, for the header and the text.
    * `:cta_url` (required) - the URL the button links to, such as the user's dashboard.
    * `:name` - the user's name, to greet them with.
    * `:intro` - a sentence under the greeting. Defaults to one about getting started.
    * `:cta_label` - the button's label. Defaults to `"Get started"`.
    * `:steps` - the first steps to take, as a list of maps with `:title` and `:description`
      keys, and optionally `:url` and `:action` (the link's text, which defaults to
      `"Start"`).
    * `:docs_url` - the URL of your guides or documentation.
    * `:support_url` - the URL to contact your team.
    * `:sign_off` - who the email is from, such as `"Maya Patel, CEO of Acme"`.
    * `:logo` - the URL of your logo. Without it, the header shows `:product_name`.
    * `:product_url` - the URL the logo links to.
    * `:address` - your company's address, for the footer.

  To change the text or the layout, copy the template into your app (see
  [Prebuilt templates](prebuilt_templates.md)).
  """

  use MjmlEEx
  import MjmlEEx.CoreComponents

  @doc "Renders the email's MJML. `to_html/1` renders it and compiles it to HTML."
  @spec render(map()) :: MjmlEEx.Rendered.t()
  attr :product_name, :string, required: true
  attr :cta_url, :string, required: true
  attr :name, :string, default: nil
  attr :intro, :string, default: nil
  attr :cta_label, :string, default: "Get started"
  attr :steps, :list, default: []
  attr :docs_url, :string, default: nil
  attr :support_url, :string, default: nil
  attr :sign_off, :string, default: nil
  attr :logo, :string, default: nil
  attr :product_url, :string, default: nil
  attr :address, :string, default: nil

  def render(assigns) do
    assigns =
      assign(assigns, :intro, assigns.intro || "We're glad you're here. Here's everything you need to get started.")

    ~MJML"""
    <.email title={"Welcome to #{@product_name}"} preview={@intro}>
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <.hero padding="40px 0 36px">
        <.heading font-size="34px" line-height="42px">
          Welcome to {@product_name}{if @name, do: ", #{@name}"}!
        </.heading>
        <.text variant="lead">{@intro}</.text>
        <.button href={@cta_url} padding="20px 25px 0">{@cta_label}</.button>
      </.hero>
      <.card :if={@steps != [] || @docs_url || @support_url || @sign_off} padding="32px 0">
        <%= if @steps != [] do %>
          <.heading level={2} padding="0 25px 8px">Your first steps</.heading>
          <.steps padding="0 25px 8px">
            <:step :for={step <- @steps} title={step.title}>
              {step.description}
              <div :if={step[:url]} style="padding-top: 4px;">
                <.link href={step.url}>{step[:action] || "Start"} &rarr;</.link>
              </div>
            </:step>
          </.steps>
        <% end %>
        <.text :if={@docs_url && @support_url}>
          Need a hand? Read <.link href={@docs_url}>the guides</.link>, or
          <.link href={@support_url}>contact our team</.link>.
        </.text>
        <.text :if={@docs_url && !@support_url}>Need a hand? Read <.link href={@docs_url}>the guides</.link>.</.text>
        <.text :if={@support_url && !@docs_url}>Need a hand? <.link href={@support_url}>Contact our team</.link>.</.text>
        <.text :if={@sign_off}>Welcome aboard,<br />{@sign_off}</.text>
      </.card>
      <.footer :if={@address}>{@address}</.footer>
    </.email>
    """
  end
end
