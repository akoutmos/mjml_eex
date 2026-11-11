defmodule MjmlEEx.Templates.Webinar do
  @moduledoc """
  A webinar invitation: the title, date and time on a banner in the theme's `primary` color,
  what attendees will learn, who's speaking, and buttons to register.

  <img src="images/templates/webinar.jpg" width="400" alt="The webinar email">

  ```elixir
  MjmlEEx.Templates.Webinar.to_html(
    product_name: "Acme",
    title: "Ship faster with Acme workflows",
    date: "Thursday, November 6, 2026",
    time: "10:00 AM PT / 1:00 PM ET",
    duration: "45 minutes",
    description: "Join our product team for a live walkthrough of Acme workflows.",
    topics: ["Automate your weekly reporting", "Hand off work between teams"],
    speakers: [%{name: "Maya Patel", role: "Head of Product, Acme"}],
    register_url: "https://acme.com/webinars/workflows",
    recording: true,
    unsubscribe_url: "https://acme.com/unsubscribe",
    address: "Acme Inc., 1 Market St, San Francisco"
  )
  ```

  ## Assigns

    * `:product_name` (required) - your product's name, for the header.
    * `:title` (required) - the webinar's title.
    * `:date` (required) - the date, such as `"Thursday, November 6, 2026"`.
    * `:time` (required) - the time, such as `"10:00 AM PT / 1:00 PM ET"`.
    * `:description` (required) - a paragraph about the webinar.
    * `:register_url` (required) - the URL of the registration page.
    * `:unsubscribe_url` (required) - the URL to unsubscribe, linked in the footer.
    * `:address` (required) - your company's postal address, for the footer.
    * `:duration` - how long the webinar is, such as `"45 minutes"`.
    * `:label` - the text above the title. Defaults to `"Live webinar"`.
    * `:topics` - what attendees will learn, as a list of strings.
    * `:speakers` - the speakers, as a list of maps with a `:name` key, and optionally
      `:role` and `:photo` (the URL of a square photo). Speakers without a photo are shown
      with their initials.
    * `:recording` - whether registered attendees get the recording. Defaults to `false`.
    * `:name` - the recipient's name, to greet them with.
    * `:preview` - the preview text. Defaults to the date and title.
    * `:logo` - the URL of your logo. Without it, the header shows `:product_name`.
    * `:product_url` - the URL the logo links to.
    * `:social` - social links for the footer, as a keyword list of `mj-social` names and
      URLs, such as `[linkedin: "https://linkedin.com/company/acme"]`.
    * `:lang` - the language of the email, for screen readers. Defaults to `"en"`, the
      language of the template's text.
    * `:dir` - the direction of the text: `"ltr"`, `"rtl"` or `"auto"` (the default). The
      template's layout stays left to right.

  To change the text or the layout, copy the template into your app (see
  [Prebuilt templates](prebuilt_templates.md)).
  """

  use MjmlEEx
  import MjmlEEx.CoreComponents

  @doc "Renders the email's MJML. `to_html/1` renders it and compiles it to HTML."
  @spec render(map()) :: MjmlEEx.Rendered.t()
  attr :product_name, :string, required: true
  attr :title, :string, required: true
  attr :date, :string, required: true
  attr :time, :string, required: true
  attr :description, :string, required: true
  attr :register_url, :string, required: true
  attr :unsubscribe_url, :string, required: true
  attr :address, :string, required: true
  attr :duration, :string, default: nil
  attr :label, :string, default: "Live webinar"
  attr :topics, :list, default: []
  attr :speakers, :list, default: []
  attr :recording, :boolean, default: false
  attr :name, :string, default: nil
  attr :preview, :string, default: nil
  attr :logo, :string, default: nil
  attr :product_url, :string, default: nil
  attr :social, :list, default: []
  attr :lang, :string, default: "en"
  attr :dir, :string, default: "auto", values: ~w(ltr rtl auto)

  def render(assigns) do
    require_text!(assigns, [:unsubscribe_url, :address])
    assigns = assign(assigns, :theme, MjmlEEx.Theme.current())

    ~MJML"""
    <.email title={@title} preview={@preview || "Join us live on #{@date}: #{@title}"} lang={@lang} dir={@dir}>
      <.header logo={@logo} logo_alt={@product_name} title={@product_name} href={@product_url} />
      <.hero padding="40px 0 32px">
        <.text variant="eyebrow">{@label}</.text>
        <.heading font-size="34px" line-height="42px" padding="4px 25px 20px">{@title}</.heading>
        <.text padding="0 25px">
          <strong>{@date}</strong><br />
          {@time}<span :if={@duration}>&nbsp;&middot;&nbsp;{@duration}</span>
        </.text>
        <.button href={@register_url} padding="24px 25px 0">Save my seat</.button>
      </.hero>
      <.card>
        <.text :if={@name}>Hi {@name},</.text>
        <.text>{@description}</.text>
        <%= if @topics != [] do %>
          <.heading level={3} padding="16px 25px 4px">What you'll learn</.heading>
          <.steps padding="0 25px 8px">
            <:step :for={topic <- @topics}>{topic}</:step>
          </.steps>
        <% end %>
        <%= if @speakers != [] do %>
          <.heading level={3} padding="16px 25px 0">{if length(@speakers) == 1, do: "Speaker", else: "Speakers"}</.heading>
          <.table rows={@speakers} padding="0 25px 8px">
            <:col :let={speaker} width="48px"><.avatar name={speaker.name} src={speaker[:photo]} /></:col>
            <:col :let={speaker}>
              <div style={"font-weight: 600; color: #{@theme.heading};"}>{speaker.name}</div>
              <div :if={speaker[:role]} style={"font-size: 14px; line-height: 20px; color: #{@theme.muted};"}>
                {speaker.role}
              </div>
            </:col>
          </.table>
        <% end %>
        <.button href={@register_url} padding="16px 25px 10px">Register now</.button>
        <.text :if={@recording} variant="small">
          Can't make it live? Register anyway and we'll send you the recording.
        </.text>
      </.card>
      <.footer>
        {@address}
        <:link href={@unsubscribe_url}>Unsubscribe</:link>
        <:social :for={{name, href} <- pairs!(@social, :social)} name={to_string(name)} href={href} />
      </.footer>
    </.email>
    """
  end

  # Marketing emails need a working unsubscribe link and a postal address, and required attrs
  # still accept nil
  defp require_text!(assigns, keys) do
    for key <- keys, not is_binary(assigns[key]) or String.trim(assigns[key]) == "" do
      raise ArgumentError, "#{inspect(__MODULE__)} requires a non-blank #{inspect(key)}, got: #{inspect(assigns[key])}"
    end
  end

  # A :for with a {_, _} pattern would leave out the elements that don't match it
  defp pairs!(nil, _assign), do: []

  defp pairs!(list, assign) do
    Enum.each(list, fn
      {_, _} ->
        :ok

      element ->
        raise ArgumentError,
              "the #{inspect(assign)} assign of #{inspect(__MODULE__)} must be a list of 2-element tuples, such as " <>
                "[x: \"https://x.com/acme\"], got: #{inspect(element)}"
    end)

    list
  end
end
