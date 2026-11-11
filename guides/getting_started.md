# Getting started

MJML EEx lets you write [MJML](https://mjml.io/) emails as Elixir templates, with the same syntax as HEEx. Templates
are parsed and checked against the MJML spec when your app compiles, and turned into email HTML by
[mjml_nif](https://github.com/adoptoposs/mjml_nif), a precompiled NIF around [MRML](https://github.com/jdrouet/mrml),
the Rust implementation of MJML. You don't need Node or Rust installed.

## Installation

Add `mjml_eex` to your dependencies in `mix.exs`. It requires Elixir 1.18 or later.

```elixir
def deps do
  [
    {:mjml_eex, "~> 1.0.0-rc.1"}
  ]
end
```

To format your templates with `mix format`, add the plugin to `.formatter.exs` (see the [Formatting](formatting.md)
guide):

```elixir
[
  import_deps: [:mjml_eex],
  plugins: [MjmlEEx.Formatter],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs,meex}"]
]
```

## Your first email

An email is a module that does `use MjmlEEx` and defines `render/1` with the `~MJML` sigil, like a LiveView or a
function component with `~H`:

```elixir
defmodule MyApp.Emails.Welcome do
  use MjmlEEx

  def render(assigns) do
    ~MJML"""
    <mjml>
      <mj-body>
        <mj-section>
          <mj-column>
            <mj-text font-size="20px" color="#F45E43">Hello {@first_name}!</mj-text>
            <mj-button :if={@cta_url} href={@cta_url}>Get started</mj-button>
          </mj-column>
        </mj-section>
      </mj-body>
    </mjml>
    """
  end
end
```

Call the generated `to_html/1` to get the HTML to send:

```elixir
html = MyApp.Emails.Welcome.to_html(first_name: "Alex", cta_url: "https://example.com")
```

`render/1` returns the rendered MJML, as an `MjmlEEx.Rendered` struct, rather than HTML. That's useful for
debugging (`MjmlEEx.to_mjml/1` gives you the MJML as a string) and for placing one template inside another.

## Template files

Like LiveView's colocated templates, you can leave `render/1` out and put the template in a `.meex` file next to the
module, with the same name:

```
lib/my_app/emails/welcome.ex
lib/my_app/emails/welcome.meex
```

```elixir
defmodule MyApp.Emails.Welcome do
  use MjmlEEx
end
```

Use the `:template` option to point somewhere else, relative to the module's file:
`use MjmlEEx, template: "templates/welcome.meex"`. A module can't have both a `render/1` and a template file.

The template is compiled into the module, so the `.meex` file isn't needed at runtime, and the module is recompiled
when the file changes.

## Sending it

MJML EEx builds the email's HTML, and a plain-text version of it with the generated `to_text/1`, so you can send
it with any mailer. Sending both, as a multipart email, helps deliverability and readers whose email client shows
plain text. With [Swoosh](https://hexdocs.pm/swoosh):

```elixir
defmodule MyApp.UserNotifier do
  import Swoosh.Email

  alias MyApp.Emails.Welcome

  def welcome(user) do
    assigns = [first_name: user.first_name, cta_url: "https://example.com"]

    new()
    |> to({user.name, user.email})
    |> from({"MyApp", "hello@example.com"})
    |> subject("Welcome to MyApp!")
    |> html_body(Welcome.to_html(assigns))
    |> text_body(Welcome.to_text(assigns))
    |> MyApp.Mailer.deliver()
  end
end
```

The plain text follows the email's content: paragraphs, lists and tables, with links written as `text (url)` and
buttons as `label: url`. See `MjmlEEx.to_text/1`.

## Translations

Templates can call any function the module defines or imports, so Gettext works as it does in Phoenix templates:

```elixir
defmodule MyApp.Emails.Welcome do
  use MjmlEEx
  use Gettext, backend: MyApp.Gettext
end
```

```heex
<mj-text>{gettext("Welcome, %{name}!", name: @first_name)}</mj-text>
```

## Next steps

- [Templates](templates.md): the template syntax and the rules specific to MJML.
- [Components](components.md): reusable function components with checked attributes and slots.
- [Core components](core_components.md): ready-made, themed components for building emails quickly.
- [Prebuilt templates](prebuilt_templates.md): complete emails for password resets, invoices, newsletters and more.
- [Layouts](layouts.md): share the head and the outer structure of your emails.
- [Validation](validation.md): what's checked at compile time, and how to configure it.
- [Testing and previewing](testing.md): test your emails, and see them in development.
