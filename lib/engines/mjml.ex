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
  def handle_expr(state, "=", {:render_component, _, [{:__aliases__, _, module}]}) do
    do_render_component(state, module, [])
  end

  def handle_expr(state, "=", {:render_component, _, [{:__aliases__, _, module}, opts]}) do
    do_render_component(state, module, opts)
  end

  def handle_expr(_state, _marker, {:render_component, _, _}) do
    raise "render_component can only be invoked inside of an <%= ... %> expression"
  end

  def handle_expr(state, marker, expr) do
    encoded_code = Utils.encode_expression(marker, expr)
    encoded_expression = "__MJML_EEX_START__:#{encoded_code}:__MJML_EEX_END__"

    %{binary: binary} = state
    %{state | binary: [encoded_expression | binary]}
  end

  defp do_render_component(state, module_alias_list, opts) do
    {mjml_component, _} =
      module_alias_list
      |> Module.concat()
      |> apply(:render, [opts])
      |> EEx.compile_string(engine: MjmlEEx.Engines.Mjml, line: 1, trim: true)
      |> Code.eval_quoted()

    %{binary: binary} = state
    %{state | binary: [mjml_component | binary]}
  end
end
