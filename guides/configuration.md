# Configuration

MJML EEx works without any configuration. This guide covers the options for compiling MJML to HTML. For the
validation settings, see [Validation](validation.md).

## Compiler options

MJML is compiled to HTML by [mjml_nif](https://github.com/adoptoposs/mjml_nif), through `MjmlEEx.Compilers.Rust`. Its
options can be set for the whole app:

```elixir
config :mjml_eex,
  compiler_opts: [
    keep_comments: false,
    fonts: %{"Noto Color Emoji": "https://fonts.googleapis.com/css?family=Noto+Color+Emoji:400"}
  ]
```

and per email, on top of the app's options:

```elixir
defmodule MyApp.Emails.Welcome do
  use MjmlEEx, compiler_opts: [social_icon_path: "https://example.com/icons/"]
end
```

| Option              | Description                                                                                          |
| ------------------- | ---------------------------------------------------------------------------------------------------- |
| `:keep_comments`    | When `false`, HTML comments are removed from the email. Defaults to `true`                           |
| `:social_icon_path` | The base URL of the `mj-social` icons                                                                |
| `:fonts`            | A map of font names (as atoms) to the URLs of their CSS files                                        |
| `:include_path`     | The directory `mj-include` paths in MJML strings are resolved from (see [Includes](includes.md))     |
| `:include_loader`   | An `Mjml.ParserOptions.LocalIncludeLoader`, as an alternative to `:include_path`                     |

Other options are ignored.

An email's `:compiler_opts` are evaluated each time `to_html/1` runs, so runtime values work:

```elixir
use MjmlEEx, compiler_opts: [social_icon_path: Application.fetch_env!(:my_app, :email_icons_url)]
```

`MjmlEEx.to_html/2` takes the same options, on top of the app's:

```elixir
MjmlEEx.to_html(mjml, keep_comments: false)
```

## Using your own compiler

To compile MJML some other way, implement the `MjmlEEx.Compiler` behaviour and configure it:

```elixir
config :mjml_eex, compiler: MyApp.MjmlCompiler
```

```elixir
defmodule MyApp.MjmlCompiler do
  @behaviour MjmlEEx.Compiler

  @impl true
  def compile(mjml, opts) do
    # Return {:ok, html} or {:error, reason}
  end
end
```

`compile/2` receives the merged compiler options. Compilers that implement only `compile/1` keep working, without
the options.

Templates are still validated against MJML 5's spec, as mjml_nif supports it. If your compiler supports something
mjml_nif doesn't, such as `mj-html-attributes`, turn the matching rule down with the
[validation settings](validation.md).
