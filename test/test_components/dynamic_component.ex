defmodule MjmlEEx.TestComponents.DynamicComponent do
  @moduledoc """
  This module defines the MJML component for the shared head block.
  """

  use MjmlEEx.Component

  @impl true
  def render(data: data) do
    """
    <p>
      #{data}
    </p>
    """
  end
end
