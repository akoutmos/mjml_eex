# Validation

MJML accepts a lot of mistakes silently. An unknown tag, a misspelled attribute or an `mj-text` placed directly in an
`mj-section` all render without an error, just not the way you meant. MJML EEx checks templates against the MJML spec
when they're compiled, and fails the build with every problem it finds:

```
== Compilation error in file lib/my_app/emails/welcome.ex ==
** (CompileError) lib/my_app/emails/welcome.ex:9: invalid MJML (2 errors):

    lib/my_app/emails/welcome.ex:9:11: mj-text cannot be used inside mj-section, only inside: mj-attributes, mj-column, mj-hero
    lib/my_app/emails/welcome.ex:9:20: Attribute colour is illegal (did you mean "color"?)
```

The spec comes from MJML 5's own component definitions. Where MJML's validator has the same rule, the message is
MJML's. Some valid MJML can't be compiled by mjml_nif, or isn't rendered the way MJML renders it. That's reported too
(see [What mjml_nif can't compile](#what-mjml_nif-can-t-compile)).

## What's checked

| Rule                   | Problem                                                                                     |
| ---------------------- | ------------------------------------------------------------------------------------------- |
| `:root`                | A document needs a single `<mjml>` root, with at most one `mj-head` and one `mj-body`       |
| `:unknown_tag`         | A tag that isn't an MJML component, or an HTML tag outside an ending tag                    |
| `:syntax`              | The template can't be parsed. This always fails                                             |
| `:unsupported_tag`     | Something mjml_nif can't compile, such as `mj-html-attributes`, `mj-raw` in `mj-social`, HTML in `mj-title`, or `<MJ-TEXT>` |
| `:invalid_child`       | A component inside a parent that doesn't allow it                                           |
| `:ending_tag`          | An MJML component inside an ending tag such as `mj-text`, whose content is HTML             |
| `:unexpected_text`     | Text directly inside a component that doesn't render text, such as `mj-column`, or text mjml_nif can't parse, such as an HTML comment in `mj-attributes` |
| `:unknown_attribute`   | An attribute the tag doesn't accept                                                         |
| `:duplicate_attribute` | The same attribute given twice                                                              |
| `:missing_attribute`   | A required attribute is missing, such as `name` on `mj-class`                               |
| `:invalid_value`       | A value that doesn't match the attribute's type: units, colors, enums and so on             |
| `:unsupported_value`   | An attribute mjml_nif ignores or handles differently than MJML, such as `mj-style inline="inline"` or `gap` on `mj-wrapper` |
| `:unknown_class`       | An `mj-class` name that isn't defined in `mj-attributes`                                    |
| `:empty_title`         | An empty `mj-title`                                                                         |
| `:component_attribute` | A [component](components.md) call with an unknown or missing attribute, or an invalid value. Attributes passed through a `:global` for an MJML tag are checked as that tag's (`:unknown_attribute`, `:invalid_value`) |
| `:component_slot`      | A component call with an unknown or missing slot                                            |

A template whose root is `<mjml>` is checked as a whole document. Other templates, such as a component that renders
a single `mj-section`, are checked on their own. An email with a [layout](layouts.md) is checked together with the
layout.

## What mjml_nif can't compile

mjml_nif compiles MJML with [MRML](https://github.com/jdrouet/mrml), which accepts less than MJML in a few places.
Where MJML would compile a template but mjml_nif wouldn't, or would render it differently, the build fails with a
message that says so:

- `mj-raw` can't be placed directly inside `mjml`, `mj-accordion`, `mj-accordion-element`, `mj-navbar` or
  `mj-social`.
- `mj-title`, `mj-preview` and `mj-accordion-title` only accept text, and `mj-title` and `mj-accordion-title` no
  comments either. `mj-breakpoint`, `mj-carousel-image`, and the tags that set default attributes in
  `mj-attributes` (including `mj-all` and `mj-class`) can't have any content, so MJML 5's `mj-class` child tags
  aren't supported. `mj-style` content can't contain `<`.
- HTML comments can't contain `--`. Outside the content of ending tags and `mj-raw`, they can only be placed directly
  in `mjml`, `mj-head`, `mj-body`, `mj-wrapper`, `mj-section`, `mj-group`, `mj-column`, `mj-hero`, `mj-accordion`,
  `mj-navbar` and `mj-social`. Outlook conditional comments (`<!--[if mso]>`) have to be in an `mj-raw`.
- MJML tags must be lowercase.
- mjml_nif ignores these attributes: `owa` on `mjml`, `font-weight` on `mj-accordion-title`, `id` on `mj-body`,
  `title` on `mj-button`, `border-radius` on `mj-hero`, `border-top`, `border-bottom` and `sizes` on `mj-image`,
  `position` on `mj-raw`, `gutter` and `text-padding` on `mj-section`, `border` and `table-layout` on `mj-social`,
  `border`, `icon-position`, `sizes` and `srcset` on `mj-social-element`, `border` and its sides on `mj-spacer`,
  `font-weight` and `role` on `mj-table`, `background-color` on `mj-text`, and `gap`, `gutter` and `text-padding` on
  `mj-wrapper`.
- mjml_nif renders `full-width="false"` (or an empty value) on `mj-section` and `mj-wrapper` as full width, and
  `mj-hero`'s `mode="fluid-height"` like `mode="fixed-height"`.
- mjml_nif doesn't inline `mj-style inline="inline"` CSS, and `mj-html-attributes` isn't supported.

## Configuring it

Every rule fails the build by default. Each rule can be set to one of three levels:

- `:error` fails the build;
- `:warn` prints a compiler warning;
- `:skip` turns the rule off.

Set a level for all the rules, or for individual ones, in your config:

```elixir
config :mjml_eex, validation: :warn
config :mjml_eex, validation: [invalid_value: :warn, unknown_class: :skip]
```

or per module, on top of the config:

```elixir
defmodule MyApp.Emails.Legacy do
  use MjmlEEx, validation: [unknown_attribute: :skip]
end
```

Templates are validated when they compile, so the `config :mjml_eex, validation: ...` setting belongs in
`config/config.exs` (or another compile-time config file), not `config/runtime.exs`: Elixir stops your app from
starting if `config/runtime.exs` gives it a different value. When you change it, Mix compiles your emails and
components again, so they're checked with the new setting.

## Values from expressions

Attribute values that come from expressions, such as `color={@color}`, are only known when the email is rendered. To
check those too, turn on runtime validation in dev and test:

```elixir
# config/dev.exs and config/test.exs
config :mjml_eex, runtime_validation: :raise
```

With `:raise`, rendering raises on an invalid value. With `:warn`, it logs a warning instead. It's off by default, or
with `false`.

It checks the `unknown_attribute`, `invalid_value` and `unsupported_value` rules, at the template's levels for them: a
rule set to `:warn` only logs, and one set to `:skip` isn't checked.

## Validating MJML strings

`MjmlEEx.validate/2` checks any MJML string, and returns `:ok` or `{:error, errors}`:

```elixir
iex> {:error, [error]} = MjmlEEx.validate(~s(<mj-text colour="red">Hi</mj-text>), parent: "mj-column")
iex> Exception.message(error)
"1:10: Attribute colour is illegal (did you mean \"color\"?)"
```

`:parent` checks a fragment as if it were placed inside that tag. To check what a template renders, pass it
through `MjmlEEx.to_mjml/1` first. That doesn't work for templates that split HTML across `mj-raw` tags with
`mjml-raw-text`, since the rendered MJML no longer has the attribute:

```elixir
MyApp.Emails.Welcome.render(first_name: "Alex") |> MjmlEEx.to_mjml() |> MjmlEEx.validate()
```
