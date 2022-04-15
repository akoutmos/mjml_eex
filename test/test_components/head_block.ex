defmodule MjmlEEx.TestComponents.HeadBlock do
  @moduledoc """
  This module defines the MJML component for the shared head block.
  """

  use MjmlEEx.Component

  @impl true
  def render(opts) do
    # Merge default options with whatever was passed in
    defaults = [title: "Welcome!", font: "Roboto"]
    opts = Keyword.merge(defaults, opts)

    """
    <mj-head>
      <mj-title>#{opts[:title]}</mj-title>
      <mj-font name="#{opts[:font]}" href="https://fonts.googleapis.com/css?family=Montserrat:300,400,500"></mj-font>
      <%= render_component MjmlEEx.TestComponents.AttributeBlock %>
    </mj-head>
    """
  end
end
