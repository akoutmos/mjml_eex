defmodule MjmlEEx.ValidationError do
  @moduledoc """
  A problem found by `MjmlEEx.validate/2`.

  - `:rule` - which rule was broken (see `t:rule/0`).
  - `:severity` - `:error` or `:warn`, from the `:validation` setting (see `MjmlEEx`).
  - `:tag` - the tag the problem is on, if any.
  - `:attribute` - the attribute the problem is on, if any.
  - `:message` - what is wrong. Where MJML's own validator has the same rule, this is
    MJML's message, for example `"Attribute colour is illegal"`.
  - `:hint` - an optional suggestion, such as `did you mean "color"?`.
  - `:file`, `:line` and `:column` - where the problem is.
  """

  @typedoc """
  The validation rules:

  - `:syntax` - the template can't be parsed.
  - `:root` - a document must have a single `<mjml>` root, which can contain at most one `mj-head` and one
    `mj-body` (plus `mj-raw` and `mj-include`).
  - `:unknown_tag` - a tag that isn't an MJML component, or an HTML tag outside an ending tag.
  - `:unsupported_tag` - an MJML component that mrml (and so mjml_nif) does not support, or
    doesn't support where it is (`mj-raw` inside `mj-social`, for example), an HTML element
    in a tag where mrml only accepts text (`mj-title`, `mj-preview`, `mj-accordion-title`), or
    an MJML tag that isn't lowercase.
  - `:invalid_child` - a component used inside a parent that doesn't allow it.
  - `:ending_tag` - an MJML tag inside an ending tag such as `mj-text`, whose content is HTML.
  - `:unexpected_text` - text directly inside a component that doesn't render text, or text
    mrml can't parse: content in `mj-breakpoint`, `mj-carousel-image` and the tags that set
    default attributes, `<` in `mj-style`, and HTML comments where mrml doesn't accept them
    (see the [Validation guide](validation.md#what-mjml_nif-can-t-compile)).
  - `:unknown_attribute` - an attribute the tag doesn't accept.
  - `:duplicate_attribute` - the same attribute given twice.
  - `:missing_attribute` - a required attribute is missing, such as `name` on `mj-class`.
  - `:invalid_value` - an attribute value that doesn't match its MJML type.
  - `:unsupported_value` - an attribute mjml_nif ignores, or a value it doesn't handle like
    MJML does (see the [Validation guide](validation.md#what-mjml_nif-can-t-compile)).
  - `:unknown_class` - an `mj-class` that isn't defined in `mj-attributes`.
  - `:empty_title` - an empty `mj-title`.
  - `:component_attribute` - a function component call with an unknown or missing attribute,
    or a literal value that doesn't match the attribute's type or `:values`.
  - `:component_slot` - a function component call with an undefined or missing slot.

  `:root`, `:unsupported_tag`, `:ending_tag`, `:unexpected_text`, `:duplicate_attribute`,
  `:missing_attribute`, `:unsupported_value`, `:unknown_class` and `:empty_title` are checks
  that MJML's own validator doesn't make.
  """
  @type rule ::
          :syntax
          | :root
          | :unknown_tag
          | :unsupported_tag
          | :invalid_child
          | :ending_tag
          | :unexpected_text
          | :unknown_attribute
          | :duplicate_attribute
          | :missing_attribute
          | :invalid_value
          | :unsupported_value
          | :unknown_class
          | :empty_title
          | :component_attribute
          | :component_slot

  @type t :: %__MODULE__{
          rule: rule(),
          severity: :error | :warn,
          tag: String.t() | nil,
          attribute: String.t() | nil,
          message: String.t(),
          hint: String.t() | nil,
          file: String.t() | nil,
          line: pos_integer() | nil,
          column: pos_integer() | nil
        }

  defexception [:rule, :severity, :tag, :attribute, :message, :hint, :file, :line, :column]

  @impl true
  def message(%__MODULE__{} = error) do
    location =
      case error do
        %{line: nil} ->
          ""

        %{file: nil} ->
          "#{error.line}:#{error.column}: "

        %{file: file} ->
          (file |> Path.relative_to_cwd() |> Exception.format_file_line_column(error.line, error.column)) <> " "
      end

    hint = if error.hint, do: " (#{error.hint})", else: ""

    "#{location}#{error.message}#{hint}"
  end
end
