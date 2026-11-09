# Formatting

MJML EEx comes with a `mix format` plugin for `.meex` files and `~MJML` sigils, ported from the HEEx formatter.

## Setup

Add the plugin to your `.formatter.exs`, include `.meex` files in `inputs`, and import MJML EEx's settings so `attr`
and `slot` are written without parentheses:

```elixir
[
  import_deps: [:mjml_eex],
  plugins: [MjmlEEx.Formatter],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs,meex}"]
]
```

If you also use `Phoenix.LiveView.HTMLFormatter`, list both plugins. Each one formats only its own sigils and file
extensions.

## What it does

- Every MJML component goes on its own line, indented. Function components and slots are laid out as in HEEx: on
  their own line when there's whitespace around them, and kept next to text they touch, since a component can render
  into an `mj-text`, where whitespace shows.
- Empty components are written self-closing: `<mj-image src="..." />`.
- When a tag's attributes don't fit within the line length, each one goes on its own line. Attributes are never
  reordered.
- Elixir code in `{...}`, `<%= ... %>` and attribute values is formatted with the Elixir formatter.
- Single `<%= ... %>` expressions outside ending tags are rewritten as `{...}`, and `<%# ... %>` comments as
  `<%!-- ... --%>`.
- Comments and intentional blank lines are kept.

## What it leaves alone

mrml copies the content of ending tags into the email HTML, where whitespace can matter, so the formatter keeps that
content exactly as written:

- ending tags, whose content is HTML: `mj-text`, `mj-button`, `mj-table`, `mj-raw`, `mj-navbar-link`,
  `mj-social-element` and so on;
- `mj-style`, `style`, `script`, `pre` and `textarea`;
- any tag with the `mjml-no-format` attribute.

Because of that, Elixir code inside an `mj-text` isn't formatted, and multi-line content keeps its indentation when
the tag moves to a different nesting level.

To skip a whole sigil, add the `noformat` modifier: `~MJML"""..."""noformat`.

## Options

Set these in `.formatter.exs`:

- `:line_length`: the maximum line length, 98 by default.
- `:mjml_line_length`: a line length for MJML templates only, if it should differ from your Elixir code's.
- `:migrate_eex_to_curly_interpolation`: whether to rewrite `<%= ... %>` as `{...}`. Defaults to `true`.
- `:attribute_formatters`: formatters for specific attributes, as for HEEx.
- `:tag_formatters`: a formatter for `mj-style` content, such as a CSS formatter. See
  `MjmlEEx.Formatter.TagFormatter`.

See `MjmlEEx.Formatter` for the details.
