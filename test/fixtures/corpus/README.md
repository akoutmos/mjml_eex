# MJML corpus

These fixtures come from [mrml](https://github.com/jdrouet/mrml), the Rust MJML implementation that
mjml_nif is built on. The exact tag and commit are recorded in `SOURCE`. mrml is MIT licensed; its
license is in `LICENSE`.

- `compare/`: the component-level fixtures from `packages/mrml-core/resources/compare/success/`.
- `template/`: the real-world templates from `packages/mrml-core/resources/template/`.

Only the `.mjml` files are vendored. mrml's `.html` files are MJML JS output, while mjml_eex compares
against mjml_nif's output for the original `.mjml`, generated during the test run.

This corpus is the regression baseline for the template engine: each fixture must keep rendering to
the same HTML as mjml_nif produces for the original file.

To re-sync, run `spec_gen/sync_corpus.sh [mrml tag]`.
