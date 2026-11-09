defmodule MjmlEEx.Rendered do
  @moduledoc """
  Rendered MJML, returned by the `~MJML` sigil and by template modules' `render/1`.

  Rendered MJML can be placed inside another template with `{...}`, where it's inserted
  as-is rather than escaped. Turn it into HTML with `MjmlEEx.to_html/2`, or into an MJML
  string with `MjmlEEx.to_mjml/1`.
  """

  @enforce_keys [:mjml]
  defstruct [:mjml]

  @type t :: %__MODULE__{mjml: iodata()}

  @doc false
  @spec from_safe(Phoenix.HTML.safe()) :: t()
  def from_safe({:safe, iodata}), do: %__MODULE__{mjml: iodata}

  defimpl Phoenix.HTML.Safe do
    def to_iodata(%MjmlEEx.Rendered{mjml: mjml}), do: mjml
  end

  defimpl String.Chars do
    def to_string(%MjmlEEx.Rendered{mjml: mjml}), do: IO.iodata_to_binary(mjml)
  end
end
