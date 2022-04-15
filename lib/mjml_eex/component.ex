defmodule MjmlEEx.Component do
  @moduledoc """
  This module allows you to define a reusable MJML component that
  can be injected into an MJML template prior to it being
  rendered into HTML.
  """

  @doc """
  Returns the MJML markup for a particular component. This callback does
  not take in any parameters
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
