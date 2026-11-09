# Layouts

Most emails from an app share the same `mj-head`, fonts, colors, header and footer. A layout holds those, and
renders each email where it has `{@inner_content}`.

## Defining a layout

A layout is an ordinary template module:

```elixir
defmodule MyApp.Emails.Layout do
  use MjmlEEx
end
```

```heex
<%!-- lib/my_app/emails/layout.meex --%>
<mjml>
  <mj-head>
    <mj-title>{@subject}</mj-title>
    <mj-attributes>
      <mj-all font-family="Helvetica, Arial, sans-serif" />
      <mj-class name="brand" color="#F45E43" />
    </mj-attributes>
  </mj-head>
  <mj-body>
    <mj-section>
      <mj-column><mj-image src="https://example.com/logo.png" alt="MyApp" /></mj-column>
    </mj-section>
    {@inner_content}
    <mj-section>
      <mj-column><mj-text font-size="12px">You're receiving this because you signed up.</mj-text></mj-column>
    </mj-section>
  </mj-body>
</mjml>
```

## Using a layout

Give the email the layout with the `:layout` option. Its template then only holds what's specific to it:

```elixir
defmodule MyApp.Emails.Welcome do
  use MjmlEEx, layout: MyApp.Emails.Layout

  def render(assigns) do
    ~MJML"""
    <mj-section>
      <mj-column>
        <mj-text mj-class="brand">Welcome, {@first_name}!</mj-text>
      </mj-column>
    </mj-section>
    """
  end
end
```

```elixir
MyApp.Emails.Welcome.to_html(subject: "Welcome to MyApp", first_name: "Alex")
```

The layout gets the same assigns as the email, including the defaults of the email's `attr` declarations, plus
`@inner_content`. `render/1` returns the email inside its layout.

A layout can also be a function component, given as `{module, function}`:

```elixir
defmodule MyApp.Emails.Components do
  use MjmlEEx.Component

  def layout(assigns) do
    ~MJML"""
    <mjml>
      <mj-body>{@inner_content}</mj-body>
    </mjml>
    """
  end
end

defmodule MyApp.Emails.Welcome do
  use MjmlEEx, layout: {MyApp.Emails.Components, :layout}
end
```

The layout runs in its own module, so it can call its own private functions. The function has to be public.

A template module used as a layout can have a layout of its own, for example a layout for a group of emails that
adds a header inside the app-wide layout.

## Validation

When an email compiles, it's validated together with its layout, as one document. The email's sections are checked
as children of the layout's `mj-body`, and the email can use the `mj-class` names defined in the layout's
`mj-attributes`, including ones that come from the layout's `mj-include` files. Problems in the layout itself are
reported once, when the layout compiles, rather than with every email that uses it.

The layout has to be a compiled MJML EEx template, so the layout module is compiled before the emails that use it. If
the two are in the same file, define the layout first.
