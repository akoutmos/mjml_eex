# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0] - 2021-05-06

### Added

- The `render_static_component` function can be used to render components that don't make use of any assigns. For
  example, in your template you would have: `<%= render_static_component MyCoolComponent, static: "data" %>` and this
  can be rendered at compile time as well as runtime.
- The `render_dynamic_component` function can be used to render components that make use of assigns at runtime. For
  example, in your template you would have: `<%= render_dynamic_component MyCoolComponent, static: @data %>`.

### Changed

- When calling `use MjmlEEx`, if the `:mjml_template` option is not provided, the module attempts to find a template
  file that has the same file name as the module (with the `.mjml.eex` extension instead of `.ex`).

### Removed

- `render_component` is no longer available and users should now use `render_static_component` or
  `render_dynamic_component`.

## [0.5.0] - 2021-04-28

### Added

- Templates can now either be compiled at runtime or at compile time based on the options passed to `use MjmlEEx`

## [0.4.0] - 2021-04-27

### Fixed

- Calls to `render_component` now evaluate the AST aliases in the context of the `__CALLER__`
- EEx templates, components and layouts are tokenized prior to going through the MJML EEx engine as not to escape MJML content

## [0.3.0] - 2021-04-17

### Added

- Ability to inject a template into a layout

## [0.2.0] - 2021-04-15

### Added

- Ability to render MJML component partials in MJML templates via `render_component`
- Macros for MJML templates
- Custom EEx engine to compile MJML EEx template to HTML
