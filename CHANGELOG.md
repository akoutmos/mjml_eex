# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-rc.1] - 2026-10-02

1.0 replaces the EEx-based template engine with a HEEx-style one. This is a breaking change; 0.x templates and modules
need updating. See the [Migrating from 0.x](guides/migrating_from_0x.md) guide.

### Added

- `MjmlEEx.CoreComponents`: ready-made components for building emails without writing styles. `email/1` renders the
  whole document, `header/1`, `hero/1`, `card/1` and `footer/1` are sections, `heading/1`, `text/1`, `button/1`,
  `badge/1`, `divider/1`, `spacer/1`, `callout/1`, `code/1`, `blockquote/1`, `table/1`, `list/1`, `checklist/1`,
  `steps/1`, `accordion/1`, `navbar/1` and `social/1` are content, and `link/1` and `avatar/1` go in text. Content in
  a hero is styled for the hero's color. `theme/1` adds the theme's defaults to a hand-written `mj-head`. See the
  [Core components](guides/core_components.md) guide.
- `MjmlEEx.Theme`: the colors, fonts and sizes of the core components. Set them for the app with
  `config :mjml_eex, :theme, ...`, or for one process with `MjmlEEx.Theme.put/1`. `MjmlEEx.Theme.validate/1` checks
  values that come from your users, such as a brand color, without raising, and `MjmlEEx.Theme.with_theme/2` sets a
  theme only while a function renders.
- Prebuilt templates for common emails, built with the core components: `MjmlEEx.Templates.Welcome`, `VerifyEmail`,
  `MagicLink`, `OneTimePassword`, `ForgotPassword`, `TeamInvitation`, `SecurityAlert`, `TrialConversion`,
  `PaymentFailed`, `Invoice`, `OrderConfirmation`, `Webinar`, `Newsletter`, `ProductLaunch` and `FlashSale`. Render
  one with your content, or copy it into your app to change it. Every template takes `:preview`, `:lang` (`"en"` by
  default) and `:dir`, and the marketing templates require an `:unsubscribe_url` and an `:address`. See the
  [Prebuilt templates](guides/prebuilt_templates.md) guide.

### Changed

- **Breaking:** Requires mjml_nif 6 (`{:mjml, "~> 6.0"}`), and Elixir 1.18 or later. If you need an older version of
  either, stay on mjml_eex 0.13.
- **Breaking:** Template modules define `render/1` with the new `~MJML` sigil, or have a colocated `.meex` template
  file (`welcome.ex` and `welcome.meex`), like LiveView. Template files use the `.meex` extension instead of
  `.mjml.eex`, and the `:template` option replaces `:mjml_template`.
- **Breaking:** `render/1` returns the rendered MJML (`MjmlEEx.Rendered`). Use the generated `to_html/1` (or
  `MjmlEEx.to_html/2`) to get the HTML.
- **Breaking:** Templates use HEEx syntax: `{...}` interpolation, `attr={...}`, `:if` and `:for`. EEx tags still
  work, except inside quoted attribute values (`attr="<%= @x %>"` becomes `attr={@x}`). A literal `{` in text must be
  written as `&#123;`. Templates are parsed at compile time, and errors point to the template's file, line and
  column.
- **Breaking:** `mj-raw` content is parsed as HTML, so its tags must be balanced. Add `mjml-raw-text` to an `mj-raw`
  to keep its content as raw text.
- **Breaking:** `mj-include` tags in templates are expanded at compile time, following MJML: paths are relative to the
  file that contains the `mj-include`, and the included files are validated with the template and don't need to
  exist at runtime. Included content renders like MJML renders it, which can differ slightly from mjml_nif's own
  include support. The `:include_path` compiler option is for MJML strings passed to `MjmlEEx.to_html/2`.
- **Breaking:** Templates are validated against the MJML spec at compile time, and every problem fails the build by
  default. Set `config :mjml_eex, validation: ...` or `use MjmlEEx, validation: ...` to turn rules (or all of them)
  down to `:warn` or `:skip`. `config :mjml_eex, runtime_validation: :raise | :warn` also checks attribute values that
  come from expressions as emails are rendered.
- **Breaking:** Requires `phoenix_html` 4.
- Compiler options, set globally with `config :mjml_eex, compiler_opts: [...]` and per template with
  `use MjmlEEx, compiler_opts: [...]`. The Rust compiler passes `:keep_comments`, `:social_icon_path`, `:fonts` and
  `:include_loader` through to `Mjml.to_html/2`, and accepts an `:include_path` shorthand for the include loader.
  Custom compilers receive them through the new `c:MjmlEEx.Compiler.compile/2` callback; compilers that only
  implement `compile/1` keep working.
- `MjmlEEx.validate/2`, which checks plain MJML against the MJML spec, and `MjmlEEx.parse/2` and `MjmlEEx.parse!/2`,
  which parse it.
- Email modules have a generated `to_text/1`, and `MjmlEEx.to_text/1` converts rendered MJML, for a plain-text
  version of an email to send with the HTML. The text follows the email's content: paragraphs, lists and tables, with
  links written as `text (url)` and buttons as `label: url`. `to_html/1` and `to_text/1` are overridable, and can
  call `super/1`.
- **Breaking:** `to_html/1` and `MjmlEEx.to_html/2` raise `MjmlEEx.CompileError`, with the compiler's `:reason` and
  the email's `:module`, instead of a `RuntimeError` when the MJML can't be compiled to HTML.
- Function components with `use MjmlEEx.Component`: `attr`, `slot`, `render_slot/2`, `:let`, named slots and `:global`
  attributes, called as `<.name>` or `<Module.name>`. They compile to direct function calls.
- Component calls are checked at compile time: unknown and missing attributes and slots, and literal values against
  their declared types and `:values`.
- Layouts: `use MjmlEEx, layout: Module` (or `{Module, :function}`) renders the email inside a template that renders
  `{@inner_content}`. A layout module can have a layout too. The email and its layouts are validated together as one
  document.
- Email modules can declare `attr`s for `render/1` (with a `.meex` template, before a bodiless `def render(assigns)`);
  `to_html/1` checks the assigns against them and applies defaults, which the layout gets too.
- Validation reports valid MJML that mjml_nif can't compile or renders differently, such as `mj-raw` in `mj-social`,
  HTML comments in `mj-attributes`, or attributes mjml_nif ignores.
- `use MjmlEEx` and `use MjmlEEx.Component` reject unknown options. `use MjmlEEx.Component` takes `validation:`.
- The `:include_path` compiler option resolves symlinks, so `Application.app_dir/2` works in dev and test.
- `MjmlEEx.Formatter`, a `mix format` plugin for `.meex` files and `~MJML` sigils, ported from the HEEx formatter.
- **Breaking:** Telemetry events are emitted by `to_html/1`. The `:mjml_template` metadata now holds the rendered
  MJML (in the `:stop` event), `:mjml_template_file` is the file the template is in, `:layout_module` is the
  layout's module, there's a new `:module` key, and `:mode` is gone.
- Guides for getting started, templates, components, layouts, includes, validation, formatting, configuration,
  telemetry, and migrating from 0.x.

### Removed

- **Breaking:** The 0.x EEx engine, `render_static_component`, `render_dynamic_component`, the 0.x
  `MjmlEEx.Component` behaviour (replaced by function components), `MjmlEEx.Layout` (layouts are now ordinary
  templates that render `{@inner_content}`) and `debug_mjml_template/0`.
- **Breaking:** `mode: :compile`. mjml_nif renders an email in microseconds, so compiling to HTML ahead of time
  isn't worth it, and filling values into precompiled HTML can't match what MJML produces when they land in
  attributes or change the structure. Templates always run their Elixir first and then compile the MJML.
- **Breaking:** The Node compiler (`MjmlEEx.Compilers.Node`) and the optional `erlexec` dependency. Templates are
  compiled with the Rust NIF. If you rely on the Node compiler, stay on mjml_eex 0.13 or implement your own compiler
  with the `MjmlEEx.Compiler` behaviour.

## [0.13.0] - 2025-12-15

- Upgraded to MJML 5.3
- Allow comments (e.g. `<%!-- this is some comment --%>`) in templates
- Bump optional `erlexec` dependency to `2.2`

## [0.12.0] - 2024-07-12

- Upgraded to MJML 4.0.0

## [0.11.0] - 2024-06-20

### Changed

- Upgraded dependencies
- Removed forked Elixir Tokenizier

## [0.10.0] - 2024-02-19

### Changed

- Upgrades the dependencies to the latest versions.

## [0.9.1] - 2023-02-13

### Changed

- Relax `phoenix_html` to make it compatible with phoenix 1.7.
- Upgrades the dependencies to the latest version.

## [0.9.0] - 2022-09-05

### Added

- MJML EEx now has Telemetry support for the rendering process. Take a look at the
  `MjmlEEx.Telemetry` module for more details.

### Changed

- The configuration options that are passed to MJML EEx have change in structure
  and there is now a `:compiler_opts` entry for options that are passed to the
  configured compiler.

## [0.8.1] - 2022-07-22

### Fixed

- Removed `:erlexec` as an `:extra_application` so it does not cause compilation errors.

## [0.8.0] - 2022-07-22

### Changed

- `:erlexec` is now an optional dependency. If you attempt to use the Node compiler without this dependency
  an error will be raised. The error message contains information on pulling it down and starting the `:erlexec`
  application.

## [0.7.0] - 2022-05-26

### Added

- You can now chose your MJML compiler. By default the Rust NIF compiler is used, but there is also an
  adapter for the Node MJML compiler.

## [0.6.0] - 2022-05-06

### Added

- The `render_static_component` function can be used to render components that don't make use of any assigns. For
  example, in your template you would have: `<%= render_static_component MyCoolComponent, static: "data" %>` and this
  can be rendered at compile time as well as runtime.
- The `render_dynamic_component` function can be used to render components that make use of assigns at runtime. For
  example, in your template you would have: `<%= render_dynamic_component MyCoolComponent, static: @data %>`.

### Changed

- When calling `use MjmlEEx`, if the `:mjml_template` option is not provided, the module attempts to find a template
  file in the same directory that has the same file name as the module (with the `.mjml.eex` extension instead
  of `.ex`). This functions similar to how Phoenix and LiveView handle their templates.

### Removed

- `render_component` is no longer available and users should now use `render_static_component` or
  `render_dynamic_component`.

## [0.5.0] - 2022-04-28

### Added

- Templates can now either be compiled at runtime or at compile time based on the options passed to `use MjmlEEx`

## [0.4.0] - 2022-04-27

### Fixed

- Calls to `render_component` now evaluate the AST aliases in the context of the `__CALLER__`
- EEx templates, components and layouts are tokenized prior to going through the MJML EEx engine as not to escape MJML content

## [0.3.0] - 2022-04-17

### Added

- Ability to inject a template into a layout

## [0.2.0] - 2022-04-15

### Added

- Ability to render MJML component partials in MJML templates via `render_component`
- Macros for MJML templates
- Custom EEx engine to compile MJML EEx template to HTML
