<p align="center">
  <img align="center" width="25%" src="guides/images/logo.svg" alt="MJML EEx Logo">
</p>

<p align="center">
  Easily create beautiful emails using <a href="https://mjml.io/" target="_blank">MJML</a> right from Elixir!
</p>

<p align="center">
  <a href="https://hex.pm/packages/mjml_eex">
    <img alt="Hex.pm" src="https://img.shields.io/hexpm/v/mjml_eex?style=for-the-badge">
  </a>

  <a href="https://github.com/akoutmos/mjml_eex/actions">
    <img alt="GitHub Workflow Status (master)"
    src="https://img.shields.io/github/workflow/status/akoutmos/mjml_eex/MJML%20EEx%20CI/master?label=Build%20Status&style=for-the-badge">
  </a>

  <a href="https://coveralls.io/github/akoutmos/mjml_eex?branch=master">
    <img alt="Coveralls master branch" src="https://img.shields.io/coveralls/github/akoutmos/mjml_eex/master?style=for-the-badge">
  </a>

  <a href="https://github.com/sponsors/akoutmos">
    <img alt="Support the project" src="https://img.shields.io/badge/Support%20the%20project-%E2%9D%A4-lightblue?style=for-the-badge">
  </a>
</p>

<br>

# Contents

- [Installation](#installation)
- [Supporting MJML EEx](#supporting-mjml_eex)
- [Using MJML EEx](#setting-up-mjml_eex)
- [Attribution](#attribution)

## Installation

[Available in Hex](https://hex.pm/packages/mjml_eex), the package can be installed by adding `mjml_eex` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mjml_eex, "~> 0.4.0"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/mjml_eex](https://hexdocs.pm/mjml_eex).

## Supporting MJML EEx

If you rely on this library to generate awesome looking emails for your application, it would much appreciated
if you can give back to the project in order to help ensure its continued development.

Checkout my [GitHub Sponsorship page](https://github.com/sponsors/akoutmos) if you want to help out!

### Gold Sponsors

<a href="https://github.com/sponsors/akoutmos/sponsorships?sponsor=akoutmos&tier_id=58083">
  <img align="center" height="175" src="guides/images/your_logo_here.png" alt="Support the project">
</a>

### Silver Sponsors

<a href="https://github.com/sponsors/akoutmos/sponsorships?sponsor=akoutmos&tier_id=58082">
  <img align="center" height="150" src="guides/images/your_logo_here.png" alt="Support the project">
</a>

### Bronze Sponsors

<a href="https://github.com/sponsors/akoutmos/sponsorships?sponsor=akoutmos&tier_id=17615">
  <img align="center" height="125" src="guides/images/your_logo_here.png" alt="Support the project">
</a>

## Using MJML EEx

### Basic Usage

Add `{:mjml_eex, "~> 0.4.0"}` to your `mix.exs` file and run `mix deps.get`. After you have that in place, you
can go ahead and create a template module like so:

```elixir
defmodule BasicTemplate do
  use MjmlEEx, mjml_template: "basic_template.mjml.eex"
end
```

And the accompanying MJML EEx template `basic_template.mjml.eex` (note that the path is relative to the calling
module path):

```html
<mjml>
  <mj-body>
    <mj-section>
      <mj-column>
        <mj-divider border-color="#F45E43"></mj-divider>
        <mj-text font-size="20px" color="#F45E43">Hello <%= @first_name %> <%= @last_name %>!</mj-text>
      </mj-column>
    </mj-section>
  </mj-body>
</mjml>
```

With those two in place, you can now run `BasicTemplate.render(first_name: "Alex", last_name: "Koutmos")` and you
will get back an HTML document that can be emailed to users.

### Using Functions from Template Module

You can also call functions from your template module if they exist in your MJML EEx template using
the following module declaration:

```elixir
defmodule FunctionTemplate do
  use MjmlEEx, mjml_template: "function_template.mjml.eex"

  defp generate_full_name(first_name, last_name) do
    "#{first_name} #{last_name}"
  end
end
```

In conjunction with the following template:

```html
<mjml>
  <mj-body>
    <mj-section>
      <mj-column>
        <mj-divider border-color="#F45E43"></mj-divider>
        <mj-text font-size="20px" color="#F45E43">Hello <%= generate_full_name(@first_name, @last_name) %>!</mj-text>
      </mj-column>
    </mj-section>
  </mj-body>
</mjml>
```

In order to render the email you would then call: `FunctionTemplate.render(first_name: "Alex", last_name: "Koutmos")`

### Using Components

In addition to compiling single MJML EEx templates, you can also create MJML partials and include them
in other MJML templates AND components using the special `render_component` function. With the following
modules:

```elixir
defmodule FunctionTemplate do
  use MjmlEEx, mjml_template: "component_template.mjml.eex"
end
```

```elixir
defmodule HeadBlock do
  use MjmlEEx.Component

  @impl true
  def render(_opts) do
    """
    <mj-head>
      <mj-title>Hello world!</mj-title>
      <mj-font name="Roboto" href="https://fonts.googleapis.com/css?family=Montserrat:300,400,500"></mj-font>
    </mj-head>
    """
  end
end
```

And the following template:

```html
<mjml>
  <%= render_component HeadBlock %>

  <mj-body>
    <mj-section>
      <mj-column>
        <mj-divider border-color="#F45E43"></mj-divider>
        <mj-text font-size="20px" color="#F45E43">Hello <%= generate_full_name(@first_name, @last_name) %>!</mj-text>
      </mj-column>
    </mj-section>
  </mj-body>
</mjml>
```

Be sure to look at the `MjmlEEx.Component` for additional usage information as you can also pass options
to your template and use them when generating the partial string.

### Using Layouts

Often times, you'll want to create an Email skeleton or layout using MJML, and then inject your template into that
layout. MJML EEx supports this functionality which makes it really easy to have business branded emails application
wide without having to copy and paste the same boilerplate in every template.

To create a layout, define a layout module like so:

```elixir
defmodule BaseLayout do
  use MjmlEEx.Layout, mjml_layout: "base_layout.mjml.eex"
end
```

And an accompanying layout like so:

```html
<mjml>
  <mj-head>
    <mj-title>Say hello to card</mj-title>
    <mj-font name="Roboto" href="https://fonts.googleapis.com/css?family=Montserrat:300,400,500"></mj-font>
    <mj-attributes>
      <mj-all font-family="Montserrat, Helvetica, Arial, sans-serif"></mj-all>
      <mj-text font-weight="400" font-size="16px" color="#000000" line-height="24px"></mj-text>
      <mj-section padding="<%= @padding %>"></mj-section>
    </mj-attributes>
  </mj-head>

  <%= @inner_content %>
</mjml>
```

As you can see, you can include assigns in your layout template (like `@padding`), but you also need to
include a mandatory `@inner_content` expression. That way, MJML EEx knowns where to inject your template
into the layout. With that in place, you just need to tell your template module what layout to use (if
you are using a layout that is):

```elixir
defmodule MyTemplate do
  use MjmlEEx,
    mjml_template: "my_template.mjml.eex",
    layout: BaseLayout
end
```

And your template file can contain merely the parts that you need for that particular template:

```html
<mj-body> ... </mj-body>
```

## Attribution

- The logo for the project is an edited version of an SVG image from the [unDraw project](https://undraw.co/)
- The Elixir MJML library that this library builds on top of [MJML](https://github.com/adoptoposs/mjml_nif)
- The Rust MRML library that provides the MJML compilation functionality [MRML](https://github.com/jdrouet/mrml)
