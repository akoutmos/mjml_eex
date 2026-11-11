# Components

Function components work like `Phoenix.Component`: a function that takes assigns and returns a template, with `attr`
and `slot` declarations. Put them in a module that does `use MjmlEEx.Component`:

```elixir
defmodule MyApp.Emails.Components do
  use MjmlEEx.Component

  attr :href, :string, required: true
  attr :rest, :global, for: "mj-button"
  slot :inner_block, required: true

  def cta(assigns) do
    ~MJML"""
    <mj-button href={@href} background-color="#F45E43" {@rest}>{render_slot(@inner_block)}</mj-button>
    """
  end
end
```

Call a component with `<.name>` when it's defined in the same module or imported, or with its full name:

```heex
<.cta href={@url} padding-top="20px">Get started</.cta>
<MyApp.Emails.Components.cta href={@url}>Get started</MyApp.Emails.Components.cta>
```

To use `<.cta>` in your emails, import the module in them. Email modules (`use MjmlEEx`) can define components too.

Keep email components in their own modules, apart from your app's `Phoenix.Component`s: both define `attr`, `slot`,
`assign` and `render_slot`, so a module can't `use` both.

MJML EEx comes with a set of ready-made components for common parts of emails, such as cards, buttons and tables. See
[Core components](core_components.md).

Calls compile to plain function calls, so components cost nothing extra when an email is rendered.

## Attributes

`attr name, type, opts` declares an attribute of the function that follows it. The types are `:string`, `:integer`,
`:boolean`, `:atom`, `:list`, `:map`, `:any` and `:global`. The options are:

- `:required`: the attribute must be given.
- `:default`: the value when the attribute isn't given.
- `:values`: the values the attribute accepts.
- `:doc`: documentation for the attribute. It's kept with the declaration, but unlike `Phoenix.Component`, it isn't
  added to the function's documentation, so describe the attributes in its `@doc` too.

```elixir
attr :title, :string, required: true
attr :align, :string, values: ~w(left center right), default: "left"
attr :items, :list, default: []
```

Attribute names are kept as written, so a declared `background-color` attribute is available as
`assigns[:"background-color"]`.

`assign/3`, `assign_new/3` and `assigns_to_attributes/2` work as they do in Phoenix.

## Global attributes

A `:global` attribute collects every attribute the caller gives that isn't declared, so it can be spread onto a tag.
With `for: "mj-button"`, it accepts the attributes `mj-button` accepts, and their values are checked against
`mj-button`'s types. With the `cta` component above, `<.cta href={@url} padding-top="20px">` passes `padding-top`
through to the `mj-button`, and `<.cta href={@url} colour="red">` is a compile error.

A `:global` attribute always accepts `mj-class` and `css-class`, and you can add more names with `include:`. That's
useful for components that spread the attributes onto an HTML tag:

```elixir
attr :href, :string, required: true
attr :rest, :global, include: ~w(target rel title)
slot :inner_block, required: true

def link(assigns) do
  ~MJML"""
  <a href={@href} {@rest}>{render_slot(@inner_block)}</a>
  """
end
```

A component can have one `:global` attribute.

## Slots

`slot name, opts` declares a slot. `:inner_block` is the content between the component's tags. Other slots are
given with `<:name>`, and can be given more than once. The options are `:required` and `:doc`, and a `do` block
declares the slot's own attributes:

```elixir
slot :column, required: true do
  attr :width, :string
end

def row(assigns) do
  ~MJML"""
  <mj-section>
    <mj-column :for={column <- @column} width={column[:width]}>
      {render_slot(column)}
    </mj-column>
  </mj-section>
  """
end
```

```heex
<.row>
  <:column width="30%"><mj-image src={@logo_url} /></:column>
  <:column><mj-text>Welcome!</mj-text></:column>
</.row>
```

`render_slot/2` renders a slot, and can pass it an argument, which the caller receives with `:let`:

```elixir
attr :items, :list, required: true
slot :inner_block, required: true

def item_list(assigns) do
  ~MJML"""
  <mj-text :for={item <- @items}>{render_slot(@inner_block, item)}</mj-text>
  """
end
```

```heex
<.item_list :let={item} items={@order.items}>
  {item.quantity} × {item.name}
</.item_list>
```

## Checked calls

Every call is checked when the template compiles:

- unknown attributes and slots, with a suggestion when there's a close match;
- missing required attributes and slots;
- literal values that don't match the attribute's type or `:values`;
- attributes passed through a `:global` attribute, against the attributes and value types of its `for:` tag.

```
** (CompileError) lib/my_app/emails/welcome.ex:12: invalid component call (1 error):

    lib/my_app/emails/welcome.ex:12:30: unknown attribute colour for <.cta> (did you mean "color"?)
```

Values that come from expressions (`href={@url}`) can't be checked at compile time. Missing attributes aren't
reported for calls that spread attributes with `{...}`, since the spread may provide them.

When the component's module isn't compiled yet, or the component is defined further down in the same module, its
calls are checked once every module is compiled.

These checks follow the [validation settings](validation.md), as the `:component_attribute` and `:component_slot`
rules.

## Checking an email's assigns

Email modules can declare `attr`s for their `render/1`. `to_html/1` then checks the assigns it's given against them,
and applies defaults, which a [layout](layouts.md) gets too:

```elixir
defmodule MyApp.Emails.Welcome do
  use MjmlEEx

  attr :first_name, :string, required: true
  attr :plan, :atom, values: [:free, :pro], default: :free

  def render(assigns) do
    ~MJML"""
    ...
    """
  end
end
```

With a `.meex` template, declare them before a `def render(assigns)` head without a body. The template is its body:

```elixir
defmodule MyApp.Emails.Welcome do
  use MjmlEEx

  attr :first_name, :string, required: true
  attr :plan, :atom, values: [:free, :pro], default: :free
  def render(assigns)
end
```

Like any `attr` declarations, they apply to the function that follows them.

```elixir
iex> MyApp.Emails.Welcome.to_html(plan: :gold)
** (ArgumentError) invalid assigns for MyApp.Emails.Welcome.to_html/1:

  * missing required attr :first_name
  * attr :plan must be one of [:free, :pro], got: :gold
```

## Where component content ends up

The content of a component call, and the attributes passed through `:global`, are checked where they're written.
What the component renders is checked inside the component. Whether the component's output is valid where it's
called, for example an `mj-section` component called inside an `mj-column`, isn't checked yet.

Content passed to a component can contain HTML, because only the component knows whether it lands inside an
ending tag such as `mj-text`.
