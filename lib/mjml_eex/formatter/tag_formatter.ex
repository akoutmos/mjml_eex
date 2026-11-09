# Adapted from Phoenix.LiveView.HTMLFormatter.TagFormatter in Phoenix LiveView v1.2.12
# (lib/phoenix_live_view/html_formatter/tag_formatter.ex, commit 83ab190).
# Phoenix LiveView is MIT licensed: Copyright (c) 2018 Chris McCord.
defmodule MjmlEEx.Formatter.TagFormatter do
  @moduledoc """
  A behaviour for formatting the content of `mj-style` tags, for example with a CSS
  formatter. Configure it in `.formatter.exs`:

  ```elixir
  [
    plugins: [MjmlEEx.Formatter],
    tag_formatters: %{"mj-style": MyApp.CSSFormatter}
  ]
  ```

  Without a tag formatter, `mj-style` content is kept exactly as written.

  `c:render_tag/2` receives `{"mj-style", attributes, content}`, where `attributes` is a map
  of the tag's literal attributes, and the `mix format` options. It returns `{:ok, content}`
  with the formatted content, or `:skip` to keep the content as written. Note that reformatted
  CSS changes the email HTML (mrml copies `mj-style` content into it), so only whitespace
  should change.
  """

  @callback render_tag(
              tag :: {String.t(), map(), String.t()},
              opts :: keyword()
            ) :: {:ok, String.t()} | :skip
end
