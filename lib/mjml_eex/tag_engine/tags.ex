defmodule MjmlEEx.TagEngine.Tags do
  @moduledoc false

  # Tag classification for the tokenizer and parser. This plays the role of
  # Phoenix.LiveView.HTMLEngine's tag handler callbacks (Phoenix LiveView v1.2.12,
  # MIT license, Copyright (c) 2018 Chris McCord).

  # The HTML spec's void elements: Phoenix.LiveView.HTMLEngine's list plus embed, track and
  # wbr, without the obsolete command and keygen, which mrml doesn't treat as void
  @void_tags ~w(area base br col embed hr img input link meta param source track wbr)

  # Elements whose content is raw text, ended only by the matching close tag
  @raw_text_tags ~w(script style mj-style)

  @no_curly_interpolation_attribute "mjml-no-curly-interpolation"
  @raw_text_attribute "mjml-raw-text"
  @no_format_attribute "mjml-no-format"

  @doc false
  def no_curly_interpolation_attribute, do: @no_curly_interpolation_attribute

  @doc false
  def raw_text_attribute, do: @raw_text_attribute

  @doc false
  def no_format_attribute, do: @no_format_attribute

  # Attributes that only mean something to mjml_eex; they're removed before compiling
  @doc false
  def mjml_eex_attributes, do: [@no_curly_interpolation_attribute, @raw_text_attribute, @no_format_attribute]

  # Mirrors Phoenix.LiveView.HTMLEngine.classify_type/1
  @doc false
  def classify_type(":inner_block"), do: {:error, "the slot name :inner_block is reserved"}
  def classify_type(":" <> name), do: {:slot, name}
  def classify_type(<<first, _::binary>> = name) when first in ?A..?Z, do: {:remote_component, name}
  def classify_type("."), do: {:error, "a component name is required after ."}
  def classify_type("." <> name), do: {:local_component, name}
  def classify_type(name), do: {:tag, name}

  @doc false
  def void?(name), do: name in @void_tags

  @doc false
  def mjml?(name), do: name == "mjml" or String.starts_with?(name, "mj-")

  # mj-raw is parsed as HTML unless it opts out with the raw text attribute (D3)
  @doc false
  def raw_text?(name, _attrs) when name in @raw_text_tags, do: true

  def raw_text?("mj-raw", attrs) do
    Enum.any?(attrs, fn
      {@raw_text_attribute, {:string, "false", _meta}, _attr_meta} -> false
      {@raw_text_attribute, _value, _meta} -> true
      _attr -> false
    end)
  end

  def raw_text?(_name, _attrs), do: false
end
