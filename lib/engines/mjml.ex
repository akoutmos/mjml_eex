defmodule MjmlEEx.Engines.Mjml do
  @moduledoc """
  This Engine is used to compile the MJML template.
  """

  alias MjmlEEx.Utils

  @behaviour EEx.Engine

  @impl true
  defdelegate init(opts), to: EEx.Engine

  @impl true
  defdelegate handle_body(state), to: EEx.Engine

  @impl true
  defdelegate handle_begin(state), to: EEx.Engine

  @impl true
  defdelegate handle_end(state), to: EEx.Engine

  @impl true
  defdelegate handle_text(state, meta, text), to: EEx.Engine

  @impl true
  def handle_expr(state, marker, expr) do
    encoded_code = Utils.encode_expression(marker, expr)
    encoded_expression = "__MJML_EEX_START__:#{encoded_code}:__MJML_EEX_END__"

    %{binary: binary} = state
    %{state | binary: [encoded_expression | binary]}
  end
end
