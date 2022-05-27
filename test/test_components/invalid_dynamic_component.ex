defmodule MjmlEEx.TestComponents.InvalidDynamicComponent do
  @moduledoc """
  This module defines the MJML component for the shared head block.
  """

  use MjmlEEx.Component

  @impl true
  def render(data: _data) do
    """
    <p>
      <%= render_dynamic_component MjmlEEx.TestComponents.DynamicComponent %>
    </p>
    """
  end
end
