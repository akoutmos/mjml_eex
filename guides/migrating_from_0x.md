# Migrating from 0.x

MJML EEx 1.0 replaces the EEx-based engine with a HEEx-style one. Most templates keep working with small changes, but
the modules around them change. This guide walks through each change. For the full list, see the
[changelog](../CHANGELOG.md).

## Requirements

- Elixir 1.18 or later.
- [mjml_nif](https://hex.pm/packages/mjml) 6 (`{:mjml, "~> 6.0"}`), which you get through MJML EEx.
- `phoenix_html` 4, if your app depends on `phoenix_html` directly.

mjml_nif 6 renders emails a little differently from the mjml_nif 5 that 0.13 used, for example with
`role="article"` and `aria-roledescription` on the email's wrapper, and different column widths in sections with
padding. Compare the HTML of a few emails when you upgrade.

The Node compiler is gone. Remove `config :mjml_eex, compiler: MjmlEEx.Compilers.Node`, and the `erlexec`
dependency if you added it for MJML EEx. To keep compiling with Node, implement your own
[compiler](configuration.md#using-your-own-compiler).

## Email modules

Rename `.mjml.eex` template files to `.meex`, and replace `:mjml_template` with `:template`, or drop it by putting the
template next to the module with the same name:

```elixir
# 0.x
defmodule MyApp.Emails.Welcome do
  use MjmlEEx, mjml_template: "welcome.mjml.eex", mode: :runtime
end

# 1.0, with lib/my_app/emails/welcome.meex
defmodule MyApp.Emails.Welcome do
  use MjmlEEx
end
```

You can also move the template into the module, in a `render/1` that uses the `~MJML` sigil. See
[Getting started](getting_started.md).

Remove the `:mode` option. Templates always run their Elixir code first and compile the resulting MJML when the email
is rendered, which takes microseconds with mjml_nif. Compile mode is gone. `use MjmlEEx` rejects options it doesn't
know, so a leftover `:mjml_template` or `:mode` is a compile error that says what to change.

## Rendering

`render/1` used to return HTML. It now returns the rendered MJML, and `to_html/1` returns the HTML. Update the places
that send emails:

```elixir
# 0.x
html = MyApp.Emails.Welcome.render(first_name: "Alex")

# 1.0
html = MyApp.Emails.Welcome.to_html(first_name: "Alex")
```

Tests that check the HTML of `render/1` need to call `to_html/1` too.

When the MJML can't be compiled to HTML, `to_html/1` raises `MjmlEEx.CompileError`, with the compiler's `:reason` and
the email's `:module`, instead of a `RuntimeError`. Update any `rescue RuntimeError` around rendering.

`debug_mjml_template/0` is gone. To see the MJML an email renders, use
`MyApp.Emails.Welcome.render(assigns) |> MjmlEEx.to_mjml()`.

## Template syntax

EEx tags in text and EEx blocks keep working, so you can convert templates gradually:

| 0.x                                         | 1.0                                                    |
| ------------------------------------------- | ------------------------------------------------------ |
| `<%= @name %>`                              | `{@name}` (`<%= @name %>` still works)                 |
| `href="<%= @url %>"`                        | `href={@url}`                                          |
| `href="<%= @base %>/welcome"`               | `href={"#{@base}/welcome"}`                            |
| `<%= if @show do %><mj-text>…<% end %>`     | `<mj-text :if={@show}>…` (the EEx block still works)   |
| `<%= for item <- @items do %>…<% end %>`    | `:for={item <- @items}` on the repeated tag            |

A few things that 0.x passed through as text no longer compile, with an error that points to them:

- EEx tags inside quoted attribute values. Change them to `attr={...}`.
- HTML tags that aren't lowercase, such as `<TD>` or `<FONT>`, since capitalized tags are components. Write them in
  lowercase.
- HTML tags that are never closed, such as `<p>one<p>two` or `<li>` without `</li>`, in `mj-text` and the other ending
  tags. Close them. Void tags such as `<br>` and `<img>` are fine.
- Attribute values without quotes, such as `<font size=2>`. Quote them.
- `<![CDATA[...]]>` sections.
- `<%%`, EEx's way of writing a literal `<%`. Write `&lt;%` instead.

`<%# ... %>` comments still compile, but with a deprecation warning from EEx (which fails builds with
`--warnings-as-errors`). `mix format` rewrites them as `<%!-- ... --%>`.

`{` now starts an expression in text, so a literal `{` outside `mj-style`, `style` and `script` needs to be written
as `&#123;` or `<%= "{" %>`, or the tag marked with `mjml-no-curly-interpolation`. Values were HTML-escaped in 0.x too, so nothing changes there.

`mj-raw` content is now parsed as HTML, so its tags must be balanced. Add `mjml-raw-text` to `mj-raw` tags that open a
wrapper and close it in another `mj-raw`. See [Templates](templates.md#mj-raw).

## Validation

Templates are now checked against the MJML spec when they compile, and every problem fails the build. Expect
to find a few real mistakes, such as attributes that don't exist on the tag they're on. While you fix them, you can
turn validation down to warnings:

```elixir
config :mjml_eex, validation: :warn
```

See [Validation](validation.md) for the rules and settings.

## Components

`render_static_component`, `render_dynamic_component` and the `MjmlEEx.Component` behaviour are replaced by function
components. A 0.x component:

```elixir
defmodule MyApp.Emails.CtaComponent do
  use MjmlEEx.Component, mode: :runtime

  @impl MjmlEEx.Component
  def render(assigns) do
    """
    <mj-button href="#{assigns[:url]}">#{assigns[:text]}</mj-button>
    """
  end
end
```

```heex
<%= render_dynamic_component MyApp.Emails.CtaComponent, url: @url, text: "Get started" %>
```

becomes a function in a components module:

```elixir
defmodule MyApp.Emails.Components do
  use MjmlEEx.Component

  attr :url, :string, required: true
  slot :inner_block, required: true

  def cta(assigns) do
    ~MJML"""
    <mj-button href={@url}>{render_slot(@inner_block)}</mj-button>
    """
  end
end
```

```heex
<MyApp.Emails.Components.cta url={@url}>Get started</MyApp.Emails.Components.cta>
```

Import `MyApp.Emails.Components` in your email modules to call it as `<.cta>`. Unlike the 0.x components, which
built a string, values are escaped, and calls are checked at compile time. Static and dynamic components are the
same thing now. See [Components](components.md).

## Layouts

`MjmlEEx.Layout` is gone. A layout is now an ordinary email module, and `@inner_content` is interpolated like any
other assign:

```elixir
# 0.x
defmodule MyApp.Emails.BaseLayout do
  use MjmlEEx.Layout, mjml_layout: "base_layout.mjml.eex"
end

# 1.0, with lib/my_app/emails/base_layout.meex
defmodule MyApp.Emails.BaseLayout do
  use MjmlEEx
end
```

In the layout's template, replace `<%= @inner_content %>` with `{@inner_content}`. Emails use it with the same
`:layout` option as before. Layouts that wrap `<mjml>` around an email's `<mj-body>` keep working, but you can also
move the `mj-body` into the layout, so emails only hold their sections. See [Layouts](layouts.md).

## `mj-include`

`mj-include` tags in templates are now expanded when the template compiles, with paths relative to the template's
file, as MJML does it. The included files no longer need to exist at runtime, and the `:include_path` compiler option
is only used for MJML strings passed to `MjmlEEx.to_html/2`. See [Includes](includes.md).

mjml_nif's own include support rendered included content slightly differently from the same content written in
place. 1.0 follows MJML, so emails that use `mj-include` can render slightly differently from 0.x, closer to what MJML
produces.

## Gettext

The `import MyApp.Gettext` no longer has to come before `use MjmlEEx`, and `use Gettext, backend: MyApp.Gettext`
works anywhere in the module.

## Telemetry

Events are now emitted by `to_html/1`. In the metadata, `:mode` is gone, `:mjml_template` holds the rendered MJML (in
the `:stop` event) instead of the template source, and `:module` is new. Without a layout, `:layout_module` is `nil`
rather than `:none`, and `:assigns` is always a map. See [Telemetry](telemetry.md).

## Formatting

Add the formatter plugin to keep templates tidy. See [Formatting](formatting.md).
