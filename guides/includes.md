# Includes

MJML's `mj-include` inserts the content of another file. MJML EEx expands `mj-include` tags when the template
compiles, following MJML's rules:

```heex
<mjml>
  <mj-body>
    <mj-include path="partials/header.mjml" />
    <mj-section>...</mj-section>
    <mj-include path="partials/footer.meex" />
  </mj-body>
</mjml>
```

- Paths are relative to the file that contains the `mj-include`: the template's file, or an included file.
- By default the file is MJML. If it's a whole `<mjml>` document, its `mj-body` content goes where the `mj-include`
  is, and its `mj-head` content is added to the template's `mj-head`. Any other file is inserted as it is.
- `type="html"` inserts the file as the content of an `mj-raw`.
- `type="css"` adds the file to the template's `mj-head` as an `mj-style`. With `css-inline="inline"`, it's an
  inlined `mj-style`, which mjml_nif doesn't support (see [Validation](validation.md)).
- Included `.meex` files are templates: they can use assigns, `{...}`, `:if`, `:for` and components. Other files are
  plain MJML.
- Includes can be nested, but not circular.

Because the files are part of the compiled template:

- they don't need to exist at runtime, in a release for example;
- they're validated with the template, and errors point into the included file;
- the template is recompiled when one of them changes.

The `path` has to be a literal string, so it can be read at compile time.

## MJML strings

`MjmlEEx.to_html/2` also compiles plain MJML strings, which aren't templates. mjml_nif resolves the `mj-include` tags
in those when it compiles them, relative to the `:include_path` compiler option (see
[Configuration](configuration.md)):

```elixir
MjmlEEx.to_html(mjml, include_path: Application.app_dir(:my_app, "priv/emails"))
```

mjml_nif's own includes don't support whole documents, or nested includes at the top of an included file, and can
render included content slightly differently from the same content written in place.
