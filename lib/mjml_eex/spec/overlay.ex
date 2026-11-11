defmodule MjmlEEx.Spec.Overlay do
  # Hand-written additions to the generated MJML spec (`MjmlEEx.Spec.Generated`).
  #
  # The generated spec only covers MJML's registered components. This module adds:
  #
  # - the components that mrml (and so mjml_nif) does not implement;
  # - attribute values that mjml_nif does not handle the way MJML does;
  # - the tags MJML accepts that are not registered components (`mj-all`, `mj-class`,
  #   `mj-selector` and `mj-html-attribute`), plus `mj-include` and the `mjml` root.
  #
  # Attribute types use the same type strings as the generated spec (see `MjmlEEx.Spec.Types`).
  @moduledoc false

  @typedoc """
  An element that is not a registered component.

  - `:allowed_attributes` - the attributes and their type strings. `:any_component_attribute`
    means any attribute that some registered component accepts (used by `mj-all` and `mj-class`).
  - `:required_attributes` - the attributes that must be present.
  """
  @type element :: %{
          allowed_attributes: %{String.t() => String.t()} | :any_component_attribute,
          required_attributes: [String.t()]
        }

  @doc """
  Components that mrml does not implement, with the reason. mjml_nif 6.0.0 fails to
  parse any document that contains `mj-html-attributes`.
  """
  @spec unsupported_tags() :: %{String.t() => String.t()}
  def unsupported_tags do
    %{
      "mj-html-attributes" => "mj-html-attributes is not supported by mrml, the MJML compiler used by mjml_nif",
      "mj-selector" => "mj-selector is not supported by mrml, the MJML compiler used by mjml_nif",
      "mj-html-attribute" => "mj-html-attribute is not supported by mrml, the MJML compiler used by mjml_nif"
    }
  end

  @doc """
  Components that mrml does not accept inside some of the parents MJML allows them in, as
  `%{component => parents}`. mjml_nif 6.0.0 fails to parse documents with them there.
  """
  @spec unsupported_children() :: %{String.t() => [String.t()]}
  def unsupported_children do
    %{"mj-raw" => ["mjml", "mj-accordion", "mj-accordion-element", "mj-navbar", "mj-social"]}
  end

  @doc """
  The tags HTML comments can be placed directly in. mrml (and so mjml_nif 6.0.0) fails to
  parse a comment directly inside any other MJML tag, a conditional comment such as
  `<!--[if mso]>` directly inside any of them, and a comment that contains `--` anywhere.
  Comments in the content of ending tags and `mj-raw` are fine.
  """
  @spec comment_parents() :: [String.t()]
  def comment_parents do
    ~w(mjml mj-head mj-body mj-wrapper mj-section mj-group mj-column mj-hero mj-accordion mj-navbar mj-social)
  end

  @doc """
  Ending tags whose content mrml restricts more than MJML does. mjml_nif 6.0.0 fails to parse
  documents that break these restrictions:

  - `:empty` - no content other than whitespace.
  - `:text` - text, without HTML elements or comments.
  - `:text_and_comments` - text and HTML comments, without HTML elements.
  - `:no_markup` - raw text without `<`.
  """
  @spec content_restrictions() :: %{String.t() => :empty | :text | :text_and_comments | :no_markup}
  def content_restrictions do
    %{
      "mj-breakpoint" => :empty,
      "mj-carousel-image" => :empty,
      "mj-title" => :text,
      "mj-accordion-title" => :text,
      "mj-preview" => :text_and_comments,
      "mj-style" => :no_markup
    }
  end

  @doc """
  Attributes and values that mjml_nif accepts but handles differently from MJML, as
  `{tag, attribute, value, reason}` tuples, where `value` is `:any` for attributes mjml_nif
  ignores whatever their value. They're reported by the `:unsupported_value` rule.

  - mjml_nif 6.0.0 builds mrml without its `css-inline` feature, so the CSS in an
    `<mj-style inline="inline">` block is output as a normal `<style>` block instead of
    being inlined into `style` attributes.
  - mrml treats `full-width="false"` (and an empty value) as full width.
  - mrml doesn't implement the other attributes listed: the HTML is the same with or
    without them.
  """
  @spec attribute_value_warnings() :: [{String.t(), String.t(), String.t() | :any, String.t()}]
  def attribute_value_warnings do
    ignored =
      for {tag, attributes} <- ignored_attributes(), attribute <- attributes do
        {tag, attribute, :any, "mjml_nif ignores the #{attribute} attribute of #{tag}"}
      end

    full_width =
      for tag <- ["mj-section", "mj-wrapper"], value <- ["false", ""] do
        {tag, "full-width", value,
         ~s(mjml_nif treats full-width="#{value}" as full width. Leave the attribute out for a normal #{tag})}
      end

    [
      {"mj-style", "inline", "inline",
       ~s(mjml_nif does not inline mj-style CSS. The CSS is output as a <style> block, which some email clients remove)},
      {"mj-hero", "mode", "fluid-height", ~s(mjml_nif renders mode="fluid-height" like mode="fixed-height")}
    ] ++ full_width ++ ignored
  end

  # Checked against mjml_nif by the "mjml_nif ignores the attributes listed" test
  @doc false
  def ignored_attributes do
    %{
      "mjml" => ["owa"],
      "mj-accordion-title" => ["font-weight"],
      "mj-body" => ["id"],
      "mj-button" => ["title"],
      "mj-hero" => ["border-radius"],
      "mj-image" => ["border-top", "border-bottom", "sizes"],
      "mj-raw" => ["position"],
      "mj-section" => ["gutter", "text-padding"],
      "mj-social" => ["border", "table-layout"],
      "mj-social-element" => ["border", "icon-position", "sizes", "srcset"],
      "mj-spacer" => ["border", "border-top", "border-bottom", "border-left", "border-right"],
      "mj-table" => ["font-weight", "role"],
      "mj-text" => ["background-color"],
      "mj-wrapper" => ["gap", "gutter", "text-padding"]
    }
  end

  @doc """
  The elements MJML accepts that are not registered components, keyed by tag name.

  - `mj-all` and `mj-class` live in `mj-attributes`. `mj-all` sets defaults for every
    component; `mj-class` defines a class that components reference with `mj-class="..."`.
  - `mj-selector` and `mj-html-attribute` live in `mj-html-attributes`. mrml does not support
    them (see `unsupported_tags/0`), but they are listed so they get a clear error rather than
    an unknown-tag error.
  - `mj-include` is resolved by the parser and can appear anywhere. `type` defaults to `mjml`.
  - `mjml` is the document root. MJML's validator skips it; MJML core reads `owa`, `lang`
    and `dir` from it, and ignores `version`, which older MJML versions used.
  """
  @spec elements() :: %{String.t() => element()}
  def elements do
    %{
      "mj-all" => %{allowed_attributes: :any_component_attribute, required_attributes: []},
      "mj-class" => %{allowed_attributes: :any_component_attribute, required_attributes: ["name"]},
      "mj-selector" => %{allowed_attributes: %{"path" => "string"}, required_attributes: ["path"]},
      "mj-html-attribute" => %{allowed_attributes: %{"name" => "string"}, required_attributes: ["name"]},
      "mj-include" => %{
        allowed_attributes: %{
          "path" => "string",
          "type" => "enum(css,html,mjml)",
          "css-inline" => "enum(inline)"
        },
        required_attributes: ["path"]
      },
      "mjml" => %{
        allowed_attributes: %{
          "owa" => "enum(desktop,mobile)",
          "lang" => "string",
          "dir" => "enum(ltr,rtl,auto)",
          # From older MJML versions; MJML and mrml ignore it
          "version" => "string"
        },
        required_attributes: []
      }
    }
  end

  @doc "Every type string used by the overlay."
  @spec type_strings() :: [String.t()]
  def type_strings do
    elements()
    |> Map.values()
    |> Enum.flat_map(fn
      %{allowed_attributes: attributes} when is_map(attributes) -> Map.values(attributes)
      _ -> []
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
