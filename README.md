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
- [Setting Up MJML EEx](#setting-up-mjml_eex)
- [Attribution](#attribution)

## Installation

[Available in Hex](https://hex.pm/packages/mjml_eex), the package can be installed by adding `mjml_eex` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mjml_eex, "~> 0.1.0"}
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

## Setting Up MJML EEx

After adding `{:mjml_eex, "~> 0.1.0"}` in your `mix.exs` file and running `mix deps.get`

With those in place, you should be all set to go!

## Attribution

- The logo for the project is an edited version of an SVG image from the [unDraw project](https://undraw.co/)
- The Elixir MJML library that this library builds on top of [MJML](https://github.com/adoptoposs/mjml_nif)
- The Rust MRML library that provides the MJML compilation functionality [MRML](https://github.com/jdrouet/mrml)
