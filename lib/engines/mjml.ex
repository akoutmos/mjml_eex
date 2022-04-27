defmodule MjmlEEx.Engines.Mjml do
  @moduledoc """
  This Engine is used to compile the MJML template.
  """

  alias MjmlEEx.Utils

  @behaviour EEx.Engine

  @impl true
  def init(opts) do
    {caller, remaining_opts} = Keyword.pop!(opts, :caller)

    remaining_opts
    |> EEx.Engine.init()
    |> Map.put(:caller, caller)
  end

  @impl true
  defdelegate handle_body(state), to: EEx.Engine

  @impl true
  defdelegate handle_begin(state), to: EEx.Engine

  @impl true
  defdelegate handle_end(state), to: EEx.Engine

  @impl true
  defdelegate handle_text(state, meta, text), to: EEx.Engine

  @impl true
  def handle_expr(state, "=", {:render_component, _, [{:__aliases__, _, _module} = aliases]}) do
    module = Macro.expand(aliases, state.caller)

    do_render_component(state, module, [], state.caller)
  end

  def handle_expr(state, "=", {:render_component, _, [{:__aliases__, _, _module} = aliases, opts]}) do
    module = Macro.expand(aliases, state.caller)

    do_render_component(state, module, opts, state.caller)
  end

  def handle_expr(_state, _marker, {:render_component, _, _}) do
    raise "render_component can only be invoked inside of an <%= ... %> expression"
  end

  def handle_expr(_state, marker, expr) do
    raise "Unescaped expression. This should never happen and is most likely a bug in MJML EEx: <%#{marker} #{Macro.to_string(expr)} %>"
  end

  defp do_render_component(state, module, opts, caller) do
    {mjml_component, _} =
      module
      |> apply(:render, [opts])
      |> Utils.escape_eex_expressions()
      |> EEx.compile_string(engine: MjmlEEx.Engines.Mjml, line: 1, trim: true, caller: caller)
      |> Code.eval_quoted()

    %{binary: binary} = state
    %{state | binary: [mjml_component | binary]}
  end
end
