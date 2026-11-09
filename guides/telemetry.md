# Telemetry

An email module's `to_html/1` runs inside a [Telemetry](https://hexdocs.pm/telemetry) span, so you can measure how
long emails take to render, and log or report failures.

## Events

| Event                                | Measurements    | When                               |
| ------------------------------------ | --------------- | ---------------------------------- |
| `[:mjml_eex, :render, :start]`     | `:system_time`  | `to_html/1` starts                 |
| `[:mjml_eex, :render, :stop]`      | `:duration`     | The HTML has been compiled         |
| `[:mjml_eex, :render, :exception]` | `:duration`     | Rendering or compiling raised      |

Every event has this metadata:

| Key                   | Value                                                                                 |
| --------------------- | ------------------------------------------------------------------------------------- |
| `:module`             | The email module                                                                      |
| `:assigns`            | The assigns, as a map                                                                 |
| `:compiler`           | The compiler module, `MjmlEEx.Compilers.Rust` unless you've configured another one    |
| `:mjml_template_file` | The file the template is in: the `.meex` file, or the module's file for `~MJML`       |
| `:layout_module`      | The layout's module, or `nil`                                                         |
| `:mjml_template`      | The rendered MJML in the `:stop` event, `nil` otherwise                               |

The `:stop` event also has `:rendered_html`, the email HTML. The `:exception` event has `:kind`, `:reason` and
`:stacktrace`.

`MjmlEEx.to_html/2` doesn't emit events.

## Example

```elixir
require Logger

:telemetry.attach(
  "log-slow-emails",
  [:mjml_eex, :render, :stop],
  fn _event, %{duration: duration}, %{module: module}, _config ->
    ms = System.convert_time_unit(duration, :native, :millisecond)
    if ms > 50, do: Logger.warning("#{inspect(module)} took #{ms}ms to render")
  end,
  nil
)
```

## Debug logging

`MjmlEEx.Telemetry.attach_logger/1` logs every event with its measurements and metadata, including the MJML and the
HTML, which is handy while you work on an email:

```elixir
MjmlEEx.Telemetry.attach_logger(level: :info)
```

The level defaults to `:debug`. Call `MjmlEEx.Telemetry.detach_logger/0` to stop.

The metadata includes the assigns and the email's content, which can contain personal data, so be careful with it in
production.
