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
    src="https://img.shields.io/github/actions/workflow/status/akoutmos/mjml_eex/main.yml?label=Build%20Status&style=for-the-badge&branch=master">
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
- [Supporting MJML EEx](#supporting-mjml-eex)
- [Using MJML EEx](#using-mjml-eex)
- [Guides](#guides)
- [Attribution](#attribution)

## Installation

[Available in Hex](https://hex.pm/packages/mjml_eex), the package can be
installed by adding `mjml_eex` to your list of dependencies in `mix.exs`. It
requires Elixir 1.18 or later.

```elixir
def deps do
  [
    {:mjml_eex, "~> 1.0.0-rc.1"}
  ]
end
```

Documentation can be found at
[https://hexdocs.pm/mjml_eex](https://hexdocs.pm/mjml_eex). Upgrading from 0.x?
See [Migrating from 0.x](guides/migrating_from_0x.md).

## Level Up Your Elixir Skills!

Everything I have learned building production Elixir systems ends up in one of
two places: an open source library on [Hex](https://hex.pm/users/akoutmos), or a
book. The libraries are free and will stay that way. The books are what let me
keep writing them.

If this library has been useful to you, picking up one of my books is the best
way to support this library and the many others that I maintain. You'll also
gain knowledge that took me years to attain!

<p align="center">
  <a target="_blank" href="https://financialelixir.dev"><img src="images/elixir_for_finance.png" width="180" /></a>
  <a target="_blank" href="https://elixirpatterns.dev"><img src="images/elixir_patterns.png" width="180" /></a>
  <a target="_blank" href="https://programmingnerves.dev"><img src="images/programming_nerves.png" width="180" /></a>
  <a target="_blank" href="https://pragprog.com/titles/passweather/build-a-weather-station-with-elixir-and-nerves"><img
  src="images/weather_station.png" width="180" /></a>
</p>

**[Elixir For Finance](https://www.financialelixir.dev)** — Learn how to
navigate markets and trading without leaving the BEAM. Livebook for exploration,
Explorer for dataframes, VegaLite for visualizations. This book goes through it
all!

**[Elixir Patterns](https://elixirpatterns.dev)** — The essential BEAM handbook
for the busy developer. The patterns and mental models covered in this book
teach you how to build scalable systems that can handle whatever production
throw at them.

**[Programming Nerves](https://www.programmingnerves.dev/)** — The best place to
start if you are looking to get your own hardware projects up and running with
Elixir and Nerves. I doubt you'll find a more fun and enjoyable hardware book
out there!

**[Build a Weather Station with Elixir and Nerves](https://pragprog.com/titles/passweather/build-a-weather-station-with-elixir-and-nerves/)**
— A project-based introduction to Nerves. Wire up the sensors, capture readings
and then pipe the data into a time series database that can be visualized with
Grafana.

## Using MJML EEx

Write emails with [MJML](https://mjml.io/) and the template syntax you know from
HEEx:

```elixir
defmodule MyApp.Emails.Welcome do
  use MjmlEEx
  import MyApp.Emails.Components

  def render(assigns) do
    ~MJML"""
    <mjml>
      <mj-body>
        <mj-section>
          <mj-column>
            <mj-text font-size="20px" color="#F45E43">Hello {@first_name}!</mj-text>
            <mj-text :for={item <- @items}>{item.name}</mj-text>
            <.cta :if={@cta_url} href={@cta_url}>Get started</.cta>
          </mj-column>
        </mj-section>
      </mj-body>
    </mjml>
    """
  end
end
```

```elixir
MyApp.Emails.Welcome.to_html(first_name: "Alex", items: items, cta_url: "https://example.com")
```

Or keep the template in a `welcome.meex` file next to the module, like
LiveView's colocated templates.

- **HEEx syntax**: `{...}` interpolation, `attr={...}`, `:if`, `:for`, and EEx
  blocks when you need them.
- **Function components** with `attr` and `slot` declarations, modeled on
  `Phoenix.Component`, and checked at compile time.
- **Core components** for polished emails without writing styles: heroes, cards,
  headings, buttons, badges, tables, callouts, a header and footer and more,
  styled with a theme you can change.
- **Prebuilt templates** for common emails: welcome emails, email confirmations,
  magic links, one-time passwords, password resets, team invitations, security
  alerts, trial conversions, failed payments, invoices, order confirmations,
  webinars, newsletters, product launches and flash sales.
- **Layouts** that share the head and outer structure of your emails.
- **Validation against the MJML spec** at compile time: unknown tags, misspelled
  attributes, invalid values and misplaced components fail the build, with the
  file, line and column.
- **Fast rendering** with [MRML](https://github.com/jdrouet/mrml), the Rust
  implementation of MJML, through the precompiled
  [mjml_nif](https://github.com/adoptoposs/mjml_nif). No Node or Rust needed.
- **Plain-text versions** of every email, for multipart emails, with the
  generated `to_text/1`.
- **A `mix format` plugin** for `.meex` files and `~MJML` sigils.
- **Telemetry** events for every rendered email.

The [prebuilt templates](guides/prebuilt_templates.md) are complete emails,
ready for your content and your theme:

<img src="guides/images/templates/gallery.jpg" width="800" alt="The prebuilt templates">

## Guides

- [Getting started](guides/getting_started.md)
- [Templates](guides/templates.md)
- [Components](guides/components.md)
- [Core components](guides/core_components.md)
- [Prebuilt templates](guides/prebuilt_templates.md)
- [Layouts](guides/layouts.md)
- [Includes](guides/includes.md)
- [Validation](guides/validation.md)
- [Formatting](guides/formatting.md)
- [Configuration](guides/configuration.md)
- [Telemetry](guides/telemetry.md)
- [Migrating from 0.x](guides/migrating_from_0x.md)

## Attribution

- The logo for the project is an edited version of an SVG image from the
  [unDraw project](https://undraw.co/)
- The Elixir MJML library that this library builds on top of
  [MJML](https://github.com/adoptoposs/mjml_nif)
- The Rust MRML library that provides the MJML compilation functionality
  [MRML](https://github.com/jdrouet/mrml)
- The attribute type validation in `lib/mjml_eex/spec/types.ex` is ported from
  [MJML](https://github.com/mjmlio/mjml)'s `mjml-core` (MIT license, Copyright
  (c) 2016 Mailjet SAS), and `lib/mjml_eex/spec/generated.ex` is generated from
  MJML's component definitions
- The test corpus in `test/fixtures/corpus/` is vendored from
  [MRML](https://github.com/jdrouet/mrml) (MIT license)
- The template tokenizer and parser (`lib/mjml_eex/tag_engine/tokenizer.ex` and
  `parser.ex`) are forked from
  [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view)'s
  tag engine (MIT license, Copyright (c) 2018 Chris McCord)
