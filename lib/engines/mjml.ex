defmodule MjmlEEx.Engines.Mjml do
  @moduledoc """
  This Engine is used to compile the MJML template.
  """

  alias MjmlEEx.Utils

  @behaviour EEx.Engine

  @impl true
  def init(opts) do
    {caller, remaining_opts} = Keyword.pop!(opts, :caller)
    {mode, remaining_opts} = Keyword.pop!(remaining_opts, :mode)
    {rendering_dynamic_component, remaining_opts} = Keyword.pop(remaining_opts, :rendering_dynamic_component, false)

    remaining_opts
    |> EEx.Engine.init()
    |> Map.put(:caller, caller)
    |> Map.put(:mode, mode)
    |> Map.put(:rendering_dynamic_component, rendering_dynamic_component)
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
  def handle_expr(%{mode: :compile}, _marker, {:render_dynamic_component, _, _}) do
    raise "render_dynamic_component can only be used with runtime generated templates. Switch your template to `mode: :runtime`"
  end

  def handle_expr(%{rendering_dynamic_component: true}, _marker, {:render_dynamic_component, _, _}) do
    raise "Cannot call `render_dynamic_component` inside of another dynamically rendered component"
  end

  def handle_expr(state, "=", {:render_dynamic_component, _, [{:__aliases__, _, _module} = aliases]}) do
    module = Macro.expand(aliases, state.caller)

    do_render_dynamic_component(state, module, [])
  end

  def handle_expr(state, "=", {:render_dynamic_component, _, [{:__aliases__, _, _module} = aliases, opts]}) do
    module = Macro.expand(aliases, state.caller)

    do_render_dynamic_component(state, module, opts)
  end

  def handle_expr(_state, _marker, {:render_dynamic_component, _, _}) do
    raise "render_dynamic_component can only be invoked inside of an <%= ... %> expression"
  end

  def handle_expr(state, "=", {:render_static_component, _, [{:__aliases__, _, _module} = aliases]}) do
    module = Macro.expand(aliases, state.caller)

    do_render_static_component(state, module, [])
  end

  def handle_expr(state, "=", {:render_static_component, _, [{:__aliases__, _, _module} = aliases, opts]}) do
    module = Macro.expand(aliases, state.caller)

    do_render_static_component(state, module, opts)
  end

  def handle_expr(_state, _marker, {:render_static_component, _, _}) do
    raise "render_static_component can only be invoked inside of an <%= ... %> expression"
  end

  def handle_expr(_state, marker, expr) do
    raise "Invalid expression. Components can only have `render_static_component` and `render_dynamic_component` EEx expression: <%#{marker} #{Macro.to_string(expr)} %>"
  end

  defp do_render_static_component(state, module, opts) do
    {mjml_component, _} =
      module
      |> apply(:render, [opts])
      |> Utils.escape_eex_expressions()
      |> EEx.compile_string(engine: MjmlEEx.Engines.Mjml, line: 1, trim: true, caller: state.caller, mode: state.mode)
      |> Code.eval_quoted()

    %{binary: binary} = state
    %{state | binary: [mjml_component | binary]}
  end

  defp do_render_dynamic_component(state, module, opts) do
    caller =
      state
      |> Map.get(:caller)
      |> :erlang.term_to_binary()
      |> Base.encode64()

    mjml_component =
      "<%= Phoenix.HTML.raw(MjmlEEx.Utils.render_dynamic_component(#{module}, #{Macro.to_string(opts)}, \"#{caller}\")) %>"

    %{binary: binary} = state
    %{state | binary: [mjml_component | binary]}
  end
end
