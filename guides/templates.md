# Templates

MJML EEx templates use the same syntax as HEEx templates. If you've written a Phoenix component, you already know
most of it. This guide covers the syntax and the few rules that are specific to MJML.

## Interpolation

`{...}` inserts the value of an Elixir expression into text, and `attribute={...}` sets an attribute's value:

```heex
<mj-text color={@brand_color}>Hello {full_name(@user)}!</mj-text>
<mj-image src={@logo_url} alt="MyApp" />
```

Values are HTML-escaped. To insert markup you trust, use `raw/1`, which is imported into every template module:

```heex
<mj-text>{raw(@signature_html)}</mj-text>
```

Templates can call any function in the module, including private ones, and anything the module imports.

Since `{` starts an expression, write a literal `{` in text as `&#123;` or `<%= "{" %>`. Inside `mj-style`, `style`
and `script` it needs no escaping (see [CSS and scripts](#css-and-scripts)).

## Attributes

In attribute values:

- `nil` and `false` leave the attribute out.
- On MJML tags, `true` renders as `attr="true"`, since MJML attribute values are strings: `fluid-on-mobile={@fluid}`.
  On HTML tags (inside an `mj-text`, for example), `true` renders the bare attribute, as in HEEx.
- On MJML tags, lists are joined with spaces, so you can build an `mj-class` from parts:
  `mj-class={["title", @highlight && "highlight"]}`. `nil` and `false` items are left out.

A map or keyword list can be spread onto a tag as attributes:

```heex
<mj-button {@button_attrs}>Get started</mj-button>
```

EEx tags can't be used inside quoted attribute values. Write `href={@url}` instead of `href="<%= @url %>"`, and
`href={"#{@base_url}/welcome"}` for a value built from parts.

## `:if` and `:for`

`:if` and `:for` work on any tag, MJML or HTML:

```heex
<mj-section :for={item <- @items}>
  <mj-column>
    <mj-text>{item.name}</mj-text>
    <mj-text :if={item.on_sale} color="#F45E43">On sale!</mj-text>
  </mj-column>
</mj-section>
```

EEx tags and blocks still work, for cases that don't fit on a single tag:

```heex
<%= case @plan do %>
  <% :pro -> %>
    <mj-text>Thanks for going Pro!</mj-text>
  <% _ -> %>
    <mj-button href={@upgrade_url}>Upgrade</mj-button>
<% end %>
```

Comments are written as `<%!-- ... --%>`, and they aren't included in the output. HTML comments (`<!-- ... -->`)
are kept in the MJML, and in the HTML unless the `keep_comments: false` compiler option is set.

## Templates inside templates

`~MJML` returns an `MjmlEEx.Rendered` struct, and placing one in another template with `{...}` inserts it as it is,
without escaping. So you can split an email into functions:

```elixir
def render(assigns) do
  ~MJML"""
  <mjml>
    <mj-body>
      {header(assigns)}
      <mj-section>...</mj-section>
    </mj-body>
  </mjml>
  """
end

defp header(assigns) do
  ~MJML"""
  <mj-section>
    <mj-column><mj-image src={@logo_url} /></mj-column>
  </mj-section>
  """
end
```

For anything you'll reuse, [function components](components.md) are usually better: they declare their attributes,
and their calls are checked when the template compiles.

## Rules specific to MJML

### CSS and scripts

`{...}` isn't interpolated inside `mj-style`, `style` and `script`, so CSS needs no escaping:

```heex
<mj-style>
  .footer a { color: #888888; }
</mj-style>
```

To turn interpolation off for the content of any other tag, add `mjml-no-curly-interpolation` to it. EEx tags still
work there.

### `mj-raw`

`mj-raw` content is parsed as HTML, so you can use `{...}`, `:if` and `:for` in it, and its tags must be balanced.
Some emails open a wrapper in one `mj-raw` and close it in another. Add `mjml-raw-text` to each of those `mj-raw` tags
so their content is kept as raw text:

```heex
<mj-raw mjml-raw-text><div class="wrapper"></mj-raw>
<mj-section>...</mj-section>
<mj-raw mjml-raw-text></div></mj-raw>
```

Like `mj-style`, an `mj-raw` with `mjml-raw-text` doesn't interpolate `{...}`, but EEx tags still work in it.

Outlook conditional comments don't need it, since comments aren't parsed:

```heex
<mj-raw><!--[if mso]><table role="presentation"><tr><td><![endif]--></mj-raw>
<mj-section>...</mj-section>
<mj-raw><!--[if mso]></td></tr></table><![endif]--></mj-raw>
```

mjml_nif does parse the HTML inside conditional comments, though, so a tag that one opens has to be closed by a later
one, as above. A conditional comment that opens a tag nobody closes makes `to_html/1` fail.

The `mjml-raw-text`, `mjml-no-curly-interpolation` and `mjml-no-format` attributes are removed before the MJML is
compiled.

### Ending tags

MJML calls tags such as `mj-text`, `mj-button` and `mj-table` "ending tags": their content is HTML, which is copied
into the email as it is. Use HTML there, not other MJML components. Elsewhere, only MJML components are allowed.
[Validation](validation.md) reports both mistakes.

## Errors

Syntax errors, such as an unclosed tag, and errors in Elixir expressions are reported when the module compiles, with
the template's file, line and column:

```
** (MjmlEEx.ParseError) lib/my_app/emails/welcome.ex:8:5: unmatched closing tag. Expected </mj-column> for <mj-column> at line 7, got: </mj-section>
  |
6 |     <mj-section>
7 |       <mj-column>
8 |     </mj-section>
  |     ^
```

If an assign a template uses isn't given, rendering raises an `ArgumentError` naming it. To check assigns before
rendering, declare them with `attr` (see [Components](components.md#checking-an-email-s-assigns)).
