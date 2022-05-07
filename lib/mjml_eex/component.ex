defmodule MjmlEEx.Component do
  @moduledoc """
  This module allows you to define a reusable MJML component that can be injected into
  an MJML template prior to it being rendered into HTML. There are two different ways
  that components can be rendered in templates. The first being `render_static_component`
  and the other being `render_dynamic_component`. `render_static_component` should be used
  to render the component when the data provided to the component is known at compile time.
  If you want to dynamically render a component (make sure that the template is set to
  `mode: :runtime`) with assigns that are passed to the template, then use
  `render_dynamic_component`.

  ## Example Usage

  To use an MjmlEEx component, create an `MjmlEEx.Component` module that looks like so:

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
  `<%= render_static_component HeadBlock %>` in your MJML EEx template.

  You can also pass options to the render function like so:

  ```elixir
  defmodule HeadBlock do
    use MjmlEEx.Component

    @impl true
    def render(opts) do
      \"""
      <mj-head>
        <mj-title>\#{opts[:title]}</mj-title>
        <mj-font name="Roboto" href="https://fonts.googleapis.com/css?family=Montserrat:300,400,500"></mj-font>
      </mj-head>
      \"""
    end
  end
  ```

  And calling it like so: `<%= render_static_component(HeadBlock, title: "Some really cool title") %>`
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
        raise "Your MjmlEEx component must implement a render/1 callback."
      end

      defoverridable MjmlEEx.Component
    end
  end
end
