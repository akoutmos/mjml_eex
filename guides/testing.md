# Testing and previewing

## Testing emails

Email modules are plain modules, so you test them like any other code: render them with assigns, and check the
result. The plain-text version from `to_text/1` is the easiest to check, since it has the email's content without the
HTML of its layout:

```elixir
defmodule MyApp.Emails.WelcomeTest do
  use ExUnit.Case, async: true

  alias MyApp.Emails.Welcome

  test "greets the user and links to the dashboard" do
    text = Welcome.to_text(first_name: "Jane", cta_url: "https://example.com/start")

    assert text =~ "Hello Jane!"
    assert text =~ "Get started: https://example.com/start"
  end

  test "compiles to HTML" do
    assert Welcome.to_html(first_name: "Jane", cta_url: "https://example.com/start") =~ "</html>"
  end
end
```

To check attributes, such as a color or a URL, assert on the MJML that `render/1` returns, before it's compiled to
HTML:

```elixir
mjml = [first_name: "Jane", cta_url: "https://example.com/start"] |> Welcome.render() |> MjmlEEx.to_mjml()
assert mjml =~ ~s(<mj-button href="https://example.com/start">)
```

Templates are validated against the MJML spec when they compile, but attribute values that come from assigns are
only known when an email renders. Turn on runtime validation in your tests, so that an invalid value, such as a color
from your data, fails the test instead of reaching your users:

```elixir
# config/test.exs
config :mjml_eex, runtime_validation: :raise
```

See [Validation](validation.md#values-from-expressions).

### Sent emails

With Swoosh's test adapter, check the emails your app sends with `Swoosh.TestAssertions`:

```elixir
import Swoosh.TestAssertions

test "sends the welcome email" do
  user = user_fixture()
  MyApp.UserNotifier.welcome(user)

  assert_email_sent(fn email ->
    assert email.subject == "Welcome to MyApp!"
    assert email.text_body =~ "Hello #{user.first_name}!"
  end)
end
```

## Previewing emails

### In Swoosh's mailbox

New Phoenix apps send emails with Swoosh's local adapter in development, and show them at `/dev/mailbox`
(`Plug.Swoosh.MailboxPreview`), with their HTML and plain-text versions. Send an email from IEx, or by using your
app, to see it there.

### On a page of your app

To see an email as you change it, without sending it, render it from a route that only exists in development:

```elixir
# lib/my_app_web/controllers/email_preview_controller.ex
defmodule MyAppWeb.EmailPreviewController do
  use MyAppWeb, :controller

  def welcome(conn, _params) do
    html(conn, MyApp.Emails.Welcome.to_html(first_name: "Jane", cta_url: "https://example.com/start"))
  end
end
```

```elixir
# lib/my_app_web/router.ex
if Application.compile_env(:my_app, :dev_routes) do
  scope "/dev" do
    pipe_through :browser

    get "/emails/welcome", MyAppWeb.EmailPreviewController, :welcome
  end
end
```

Phoenix recompiles your app when you reload the page, including emails whose `.meex` template changed. To have the
page reload by itself, add your emails to the live reload patterns in `config/dev.exs`:

```elixir
config :my_app, MyAppWeb.Endpoint,
  live_reload: [
    patterns: [
      # ...your existing patterns
      ~r"lib/my_app/emails/.*\.(ex|meex)$"
    ]
  ]
```
