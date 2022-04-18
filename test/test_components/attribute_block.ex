defmodule MjmlEEx.TestComponents.AttributeBlock do
  @moduledoc """
  This module defines the MJML component for the shared attribute block.
  """

  use MjmlEEx.Component

  @impl true
  def render(_opts) do
    """
    <mj-attributes>
      <mj-all font-family="Montserrat, Helvetica, Arial, sans-serif"></mj-all>
      <mj-text font-weight="400" font-size="16px" color="#000000" line-height="24px"></mj-text>
      <mj-section padding="0px"></mj-section>
    </mj-attributes>
    """
  end
end
