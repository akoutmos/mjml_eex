defmodule MjmlEEx.Test.Components do
  @moduledoc false

  # 1.0 versions of the 0.13 test components, plus slot examples
  use MjmlEEx.Component

  attr :title, :string, default: "Welcome!"
  attr :font, :string, default: "Roboto"

  def head_block(assigns) do
    ~MJML"""
    <mj-head>
      <mj-title>{@title}</mj-title>
      <mj-font name={@font} href="https://fonts.googleapis.com/css?family=Montserrat:300,400,500" />
      <.attribute_block />
    </mj-head>
    """
  end

  def attribute_block(assigns) do
    ~MJML"""
    <mj-attributes>
      <mj-all font-family="Montserrat, Helvetica, Arial, sans-serif" />
      <mj-text font-weight="400" font-size="16px" color="#000000" line-height="24px" />
      <mj-section padding="0px" />
    </mj-attributes>
    """
  end

  attr :rest, :global, for: "mj-section", include: ~w(data-section)
  slot :inner_block

  def section(assigns) do
    ~MJML"""
    <mj-section {@rest}>{render_slot(@inner_block)}</mj-section>
    """
  end

  attr :data, :string, required: true

  def data_row(assigns) do
    ~MJML"""
    <mj-text>{@data}</mj-text>
    """
  end

  attr :href, :string, required: true
  attr :rest, :global, for: "mj-button"
  slot :inner_block, required: true

  def cta(assigns) do
    ~MJML"""
    <mj-button href={@href} {@rest}>{render_slot(@inner_block)}</mj-button>
    """
  end

  attr :items, :list, required: true

  slot :column, doc: "A column, rendered for every item" do
    attr :width, :string
  end

  def table(assigns) do
    ~MJML"""
    <mj-section :for={item <- @items}>
      <mj-column :for={column <- @column} width={column[:width]}>
        {render_slot(column, item)}
      </mj-column>
    </mj-section>
    """
  end
end
