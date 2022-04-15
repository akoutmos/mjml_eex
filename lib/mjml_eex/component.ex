defmodule MjmlEEx.Component do
  @moduledoc """
  This module allows you to define a reusable MJML component that
  can be injected into an MJML template prior to it being
  rendered into HTML. To do so, create an `MjmlEEx.Component`
  module that looks like so:

  ```elixir
  defmodule HeadBlock do
    use MjmlEEx.Component

    @impl true
    def render(_opts) do
      \"""
      <mj-head>
        <mj-title>Hello world!</mj-title>
        <mj-font name="Roboto" href="https://fonts.googleapis.com/css?family=Montserrat:300,400,500"></mj-font>
      </mj-head>
      \"""
    end
  end
  ```

  With that in place, anywhere that you would like to use the component, you can add:
  `<%= render_component HeadBlock %>` in your MJML EEx template.

  You can also pass options to the render function like so:

  ```elixir
  defmodule HeadBlock do
    use MjmlEEx.Component

    @impl true
    def render(opts) do
      \"""
      <mj-head>
        <mj-title><%= opts[:title] %></mj-title>
        <mj-font name="Roboto" href="https://fonts.googleapis.com/css?family=Montserrat:300,400,500"></mj-font>
      </mj-head>
      \"""
    end
  end
  ```

  And calling it like so: `<%= render_component(HeadBlock, title: "Some really cool title") %>`
  """

  @doc """
  Returns the MJML markup for the component as a string.
  """
  @callback render(opts :: keyword()) :: String.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour MjmlEEx.Component

      @impl true
      def render(_opts) do
        raise "Your MjmlEEx component must implement a render/1 callback"
      end

      defoverridable MjmlEEx.Component
    end
  end
end
