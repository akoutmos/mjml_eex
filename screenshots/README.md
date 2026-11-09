# Template screenshots

The screenshots of the prebuilt templates in `guides/images/templates/`, and the gallery of them in `gallery.jpg`,
are made by a dev-only task:

```sh
mix mjml_eex.gen.screenshots                  # every template, and the gallery
mix mjml_eex.gen.screenshots welcome invoice  # just these templates
```

It needs macOS and Swift, which comes with the Xcode command line tools (`xcode-select --install`). The screenshots
are taken with WebKit, the engine of Apple Mail and Safari. Taking them all takes about 15 seconds, and the same
templates always make the same files, so git only shows the screenshots that changed.

Run it after changing a template, a core component or the default theme, and commit the images it changes.

## How it works

- `examples.exs` has the content of each template's screenshot, in the order of the gallery, and the size of each
  example image.
- `art/` has the example images: a logo, a product screenshot, article images and product photos, drawn in HTML and
  CSS, so there are no photos to license. The task screenshots them first, to `art/*.png` next to the emails, which
  is how the examples refer to them (`logo: "art/logo.png"`).
- `mix/mjml_eex.gen.screenshots.ex` renders each example with `to_html/1`, with runtime validation on, and writes the
  emails, the gallery's page and a list of jobs to `_build/dev/screenshots/`. Open the emails there to see what was
  screenshotted.
- `snapshot.swift` takes a screenshot of each page in the list, and saves the emails as JPEGs, 1020 pixels wide.

None of this is in the Hex package.

## Adding a template

1. Add the module to `lib/mjml_eex/templates/`. Show its screenshot in its `@moduledoc`, like the other templates do:
   `<img src="images/templates/<name>.jpg" width="400" alt="...">`, where `<name>` is the module's name in
   snake case (`flash_sale` for `MjmlEEx.Templates.FlashSale`).
2. Add an example of it to `examples.exs`, at its place in the gallery. If it needs a new image, draw one in `art/`
   and add its size to the `art` list.
3. Run `mix mjml_eex.gen.screenshots`, and look at the screenshot and the gallery. The gallery has five templates a
   row.
4. Add the template to `guides/prebuilt_templates.md`, to the `Prebuilt templates` group in `mix.exs`, to the tests in
   `test/mjml_eex/templates_test.exs` and to the changelog.

`mix test` checks that every template has a test, an example here, a screenshot, a place in the guide and in
`mix.exs`, and that every example renders valid MJML.
