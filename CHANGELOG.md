# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2021-04-28

### Added

- Templates can now either be compiled at runtime or at compile time based on the options passed to `use MjmlEEx`

### Fixed

- Calls to `render_component` now evaluate the AST aliases in the context of the `__CALLER__`
- EEx templates, components and layouts are tokenized prior to going through the MJML EEx engine as not to escape MJML content

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
