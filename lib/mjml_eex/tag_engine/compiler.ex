# Adapted from Phoenix.LiveView.TagEngine.Compiler in Phoenix LiveView v1.2.12
# (lib/phoenix_live_view/tag_engine/compiler.ex, https://github.com/phoenixframework/phoenix_live_view,
# commit 83ab190): the EEx block placeholder approach, `:if`/`:for` handling and attribute
# validation. Phoenix LiveView is MIT licensed: Copyright (c) 2018 Chris McCord.
#
# Unlike upstream, this compiles to Phoenix.HTML.Engine (plain iodata, no change tracking),
# and there are no components, slots or debug annotations yet.
defmodule MjmlEEx.TagEngine.Compiler do
  @moduledoc false

  alias MjmlEEx.Component.Calls
  alias MjmlEEx.{ParseError, Validator}
  alias MjmlEEx.TagEngine.{Includes, Parser, Runtime, Tags}

  @engine Phoenix.HTML.Engine

  @doc false
  @spec compile(String.t(), keyword()) :: Macro.t()
  def compile(source, opts) do
    file = Keyword.get(opts, :file, "nofile")
    indentation = Keyword.get(opts, :indentation, 0)

    parser_opts = [
      file: file,
      line: Keyword.get(opts, :line, 1),
      column: Keyword.get(opts, :column, 1),
      indentation: indentation,
      interpolation: true,
      trim_eex: false,
      strip_eex_comments: true
    ]

    nodes = Parser.parse!(source, parser_opts)
    {nodes, included_files} = Includes.expand(nodes, file)
    track_files(included_files, opts[:caller])
    # Templates are validated with their layouts, so they're compiled again when one changes
    track_files(opts |> Keyword.get(:layout) |> List.wrap() |> Enum.map(& &1.file), opts[:caller])
    validate!(nodes, file, Keyword.get(opts, :validation), Keyword.get(opts, :layout), opts[:caller])

    state = %{
      file: file,
      source: ParseError.snippet_source(source, Keyword.get(opts, :line, 1)),
      indentation: indentation,
      caller: Keyword.get(opts, :caller),
      levels: Validator.levels(Keyword.get(opts, :validation))
    }

    substate = handle_node(nodes, @engine.init([]), state)
    ast = substate |> @engine.handle_body() |> merge_static()

    quote do
      MjmlEEx.Rendered.from_safe(unquote(ast))
    end
  end

  # The engine adds each piece of static markup ("<mj-text", ">", ...) as its own binary.
  # Joining adjacent ones makes the code much faster to compile (the Erlang compiler is slow
  # with long lists of literals between variables) and the iodata shorter.
  defp merge_static(ast) do
    Macro.prewalk(ast, fn
      {:safe, list} when is_list(list) ->
        merged =
          list
          |> Enum.chunk_by(&is_binary/1)
          |> Enum.flat_map(fn
            [binary | _] = binaries when is_binary(binary) -> [IO.iodata_to_binary(binaries)]
            others -> others
          end)

        {:safe, merged}

      node ->
        node
    end)
  end

  # Included files are recompiled into the template when they change
  defp track_files([], _caller), do: :ok

  defp track_files(files, %Macro.Env{module: module}) when is_atom(module) and not is_nil(module) do
    if Module.open?(module), do: Enum.each(files, &Module.put_attribute(module, :external_resource, &1))
  end

  defp track_files(_files, _caller), do: :ok

  ## Validation

  # A template whose root is <mjml> is validated as a document; anything else is a
  # fragment, whose surroundings are only known where it's used. Errors fail the
  # compilation, warnings are printed with the template location.
  defp validate!(nodes, file, validation, layout, caller) do
    levels = Validator.levels(validation)

    if Enum.any?(levels, fn {_rule, level} -> level != :skip end) do
      problems =
        case layout do
          nil ->
            Validator.validate(nodes, file: file, levels: levels, fragment: not document?(nodes))

          layouts ->
            # Problems in the layouts themselves were reported when they compiled. A layout
            # can render {@inner_content} more than once, so the same problem can show up twice.
            composed = Enum.reduce(List.wrap(layouts), nodes, &compose_with_layout(&2, &1, file, caller))

            composed
            |> Validator.validate(file: file, levels: levels, fragment: not document?(composed))
            |> Enum.reject(&match?({:layout, _file}, &1.file))
            |> Enum.uniq_by(&{&1.file, &1.line, &1.column, &1.message})
        end

      {errors, warnings} = Enum.split_with(problems, &(&1.severity == :error))

      for warning <- warnings do
        IO.warn(describe(warning), file: warning.file, line: warning.line, column: warning.column)
      end

      case errors do
        [] ->
          :ok

        [first | _] ->
          details = Enum.map_join(errors, "\n", &("    " <> Exception.message(&1)))

          raise CompileError,
            file: first.file,
            line: first.line,
            description:
              "invalid MJML (#{length(errors)} #{pluralize(errors)}):\n\n#{details}\n" <> Validator.rules_hint(errors)
      end
    end
  end

  # The template inside its layout, where the layout renders {@inner_content}. Layout nodes are
  # marked with {:layout, file} as their file, so their problems can be told apart.
  defp compose_with_layout(nodes, layout, file, caller) do
    layout_nodes =
      Parser.parse!(layout.source,
        file: layout.file,
        line: layout.line,
        column: layout.column,
        indentation: layout.indentation,
        interpolation: true,
        trim_eex: false,
        strip_eex_comments: true
      )

    # Includes in the layout are part of it
    {layout_nodes, included_files} = Includes.expand(layout_nodes, layout.file)
    track_files(included_files, caller)

    case replace_inner_content(Includes.mark_file(layout_nodes, {:layout, layout.file}), nodes) do
      {composed, true} ->
        composed

      {_composed, false} ->
        raise CompileError,
          file: file,
          line: (caller && caller.line) || 1,
          description: "the layout in #{Path.relative_to_cwd(layout.file)} doesn't render {@inner_content}"
    end
  end

  defp replace_inner_content(nodes, inner) do
    Enum.flat_map_reduce(nodes, false, fn node, found? ->
      cond do
        inner_content?(node) ->
          {inner, true}

        match?({:block, _, _, _, _, _, _}, node) ->
          {:block, type, name, attrs, children, meta, close} = node
          {children, found_inside?} = replace_inner_content(children, inner)
          {[{:block, type, name, attrs, children, meta, close}], found? or found_inside?}

        match?({:eex_block, _, _, _}, node) ->
          {:eex_block, expr, clauses, meta} = node

          {clauses, found_inside?} =
            Enum.map_reduce(clauses, false, fn {children, clause, clause_meta}, acc ->
              {children, found_inside?} = replace_inner_content(children, inner)
              {{children, clause, clause_meta}, acc or found_inside?}
            end)

          {[{:eex_block, expr, clauses, meta}], found? or found_inside?}

        true ->
          {[node], found?}
      end
    end)
  end

  defp inner_content?({:body_expr, expr, _meta}), do: String.trim(expr) == "@inner_content"
  defp inner_content?({:eex, expr, %{opt: ~c"="}}), do: String.trim(expr) == "@inner_content"
  defp inner_content?(_node), do: false

  defp describe(%{message: message, hint: nil}), do: message
  defp describe(%{message: message, hint: hint}), do: "#{message} (#{hint})"

  defp pluralize([_]), do: "error"
  defp pluralize(_errors), do: "errors"

  defp document?(nodes) do
    Enum.any?(nodes, fn
      {:block, :tag, "mjml", _attrs, _children, _meta, _close} -> true
      {:self_close, :tag, "mjml", _attrs, _meta} -> true
      {:eex_block, _expr, clauses, _meta} -> Enum.any?(clauses, fn {children, _, _} -> document?(children) end)
      _node -> false
    end)
  end

  ## Nodes

  defp handle_node(nodes, substate, state) when is_list(nodes) do
    Enum.reduce(nodes, substate, &handle_node(&1, &2, state))
  end

  defp handle_node({:text, "", _meta}, substate, _state), do: substate
  defp handle_node({:text, text, _meta}, substate, _state), do: @engine.handle_text(substate, [], text)
  defp handle_node({:eex_comment, _text, _meta}, substate, _state), do: substate

  ## {...} interpolation
  defp handle_node({:body_expr, expr, meta}, substate, state) do
    ast = quoted!(expr, meta, state)
    @engine.handle_expr(substate, "=", to_safe(ast))
  end

  ## <%= ... %> and <% ... %>
  defp handle_node({:eex, expr, %{opt: opt} = meta}, substate, state) do
    ast = quoted!(expr, meta, state)
    ast = if opt == ~c"=", do: to_safe(ast), else: ast
    @engine.handle_expr(substate, to_string(opt), ast)
  end

  ## EEx blocks (if/case/cond/for). Like EEx.Compiler, the whole expression is built
  ## as a string with __EEX__(key) placeholders, parsed, and the placeholders are
  ## replaced with each clause's compiled content.
  defp handle_node({:eex_block, expr, blocks, %{line: line, column: column, opt: opt} = meta}, substate, state) do
    {quoted, combined_expr, _line, _seen_clause?} =
      Enum.reduce(blocks, {[], expr, line, false}, fn
        {children, clause_expr, clause_meta}, {quoted, acc_expr, prev_line, seen_clause?} ->
          newlines = String.duplicate("\n", clause_meta.line - prev_line)

          if all_spaces?(children) and not seen_clause? and stab_clause?(clause_expr) do
            # `case x do %><% pattern -> %>`: no placeholder before the first clause
            {quoted, acc_expr <> newlines <> " " <> clause_expr, clause_meta.line, true}
          else
            clause_ast = children |> handle_node(@engine.handle_begin(substate), state) |> @engine.handle_end()
            key = length(quoted)
            acc_expr = acc_expr <> " __EEX__(#{key});" <> newlines <> " " <> clause_expr
            {[{key, clause_ast} | quoted], acc_expr, clause_meta.line, true}
          end
      end)

    block_ast = quoted!(combined_expr, meta, state, column: column + 2 + length(opt))

    @engine.handle_expr(substate, to_string(opt), insert_quoted(block_ast, quoted))
  end

  ## Elements
  defp handle_node({:block, :tag, name, attrs, children, meta, _close_meta}, substate, state) do
    with_special_attrs(attrs, meta, substate, state, fn attrs, substate ->
      substate = handle_tag_and_attrs(name, attrs, ">", substate, state)
      substate = handle_node(children, substate, state)
      @engine.handle_text(substate, [], "</#{name}>")
    end)
  end

  defp handle_node({:self_close, :tag, name, attrs, meta}, substate, state) do
    suffix = if meta.closing == :void, do: ">", else: " />"

    with_special_attrs(attrs, meta, substate, state, fn attrs, substate ->
      handle_tag_and_attrs(name, attrs, suffix, substate, state)
    end)
  end

  ## Function components (<.name> and <Mod.name>). Slots are handled by their component.
  ## Adapted from LiveView's compiler: the inner block and each slot entry become closures
  ## that render_slot/2 calls, with :let patterns as their arguments.
  defp handle_node({:block, type, name, attrs, children, meta, _close}, substate, state)
       when type in [:local_component, :remote_component] do
    handle_component(type, name, attrs, children, meta, substate, state)
  end

  defp handle_node({:self_close, type, name, attrs, meta}, substate, state)
       when type in [:local_component, :remote_component] do
    handle_component(type, name, attrs, nil, meta, substate, state)
  end

  defp handle_component(type, name, attrs, children, meta, substate, state) do
    with_special_attrs(attrs, meta, substate, state, fn attrs, substate ->
      {let, attrs} = pop_let(attrs, state)

      if let && children == nil do
        raise_syntax_error!("cannot use :let on a component without inner content", elem(let, 1), state)
      end

      # Checks the name first, so an invalid one gets a syntax error
      fun = component_fun(type, name, meta, state)
      {roots, attr_pairs} = component_attrs(attrs, "component #{display_name(type, name)}", state)
      check_component_call(type, name, attrs, children, meta, state)
      slot_pairs = if children, do: slot_assigns(children, let, substate, state), else: []
      assigns = merge_assigns(roots, attr_pairs ++ slot_pairs)

      ast =
        quote line: meta.line do
          MjmlEEx.Component.__call__(unquote(fun), unquote(assigns))
        end

      @engine.handle_expr(substate, "=", ast)
    end)
  end

  ## Component call checks (see MjmlEEx.Component.Calls)

  defp check_component_call(_type, _name, _attrs, _children, _meta, %{caller: nil}), do: :ok

  defp check_component_call(type, name, attrs, children, meta, %{caller: caller} = state) do
    {module, fun} = component_target(type, name, caller)

    call = %{
      module: module,
      fun: fun,
      display: display_name(type, name),
      file: file(meta, state),
      line: meta.line,
      column: meta.column,
      root: Enum.any?(attrs, &match?({:root, _, _}, &1)),
      attrs: call_attrs(attrs, state),
      slots: call_slots(children || [], state),
      inner_block: children != nil,
      levels: state.levels
    }

    # Calls in template modules are recorded, to be checked again by @after_verify
    calls = caller.module && Module.open?(caller.module) && Module.get_attribute(caller.module, :__mjml_eex_calls__)
    Calls.check_now(call, caller, is_list(calls))
    if is_list(calls), do: Module.put_attribute(caller.module, :__mjml_eex_calls__, [call | calls])

    :ok
  end

  # Local calls go to the caller's module, or the module the function is imported from
  defp component_target(:local_component, name, caller) do
    fun = String.to_atom(name)

    case Macro.Env.lookup_import(caller, {fun, 1}) do
      [{_kind, module} | _] -> {module, fun}
      [] -> {caller.module, fun}
    end
  end

  defp component_target(:remote_component, name, caller) do
    [fun | aliases] = name |> String.split(".") |> Enum.reverse()
    aliases = aliases |> Enum.reverse() |> Enum.map(&String.to_atom/1)
    {Macro.expand({:__aliases__, [], aliases}, caller), String.to_atom(fun)}
  end

  defp call_attrs(attrs, state) do
    for {name, value, meta} <- attrs, is_binary(name), not String.starts_with?(name, ":") do
      {String.to_atom(name), meta.line, meta.column, call_value(value, state)}
    end
  end

  defp call_value(nil, _state), do: {:literal, true}
  defp call_value({:string, value, _meta}, _state), do: {:literal, value}

  defp call_value({:expr, _, _} = expr, state) do
    ast = parse_expr!(expr, state)

    if Macro.quoted_literal?(ast) do
      {value, _binding} = Code.eval_quoted(ast)
      {:literal, value}
    else
      :expr
    end
  end

  defp call_slots(children, state) do
    for {kind, :slot, name, attrs, _, meta, _} <- Enum.map(children, &pad_node/1), kind in [:block, :self_close] do
      %{
        name: String.to_atom(name),
        line: meta.line,
        column: meta.column,
        root: Enum.any?(attrs, &match?({:root, _, _}, &1)),
        attrs: call_attrs(attrs, state)
      }
    end
  end

  # Gives self-closing nodes the same shape as blocks, for the comprehension above
  defp pad_node({:self_close, type, name, attrs, meta}), do: {:self_close, type, name, attrs, [], meta, nil}
  defp pad_node(node) when tuple_size(node) == 7, do: node
  defp pad_node(_node), do: {:other, nil, nil, [], [], nil, nil}

  defp display_name(:local_component, name), do: "<.#{name}>"
  defp display_name(:remote_component, name), do: "<#{name}>"

  defp component_fun(:local_component, name, meta, _state) do
    call = {String.to_atom(name), [line: meta.line, column: meta.column], __MODULE__}
    quote(do: &(unquote(call) / 1))
  end

  defp component_fun(:remote_component, name, meta, state) do
    case name |> String.split(".") |> Enum.reverse() do
      [<<first, _::binary>> = fun | [_ | _] = aliases] when first in ?a..?z ->
        aliases = aliases |> Enum.reverse() |> Enum.map(&String.to_atom/1)
        module = {:__aliases__, [line: meta.line, column: meta.column], aliases}
        quote(line: meta.line, do: &(unquote(module).unquote(String.to_atom(fun)) / 1))

      [_name] ->
        raise_syntax_error!(
          "invalid tag <#{name}>. HTML tags are written in lowercase (<#{String.downcase(name)}>), and components are called as <.function> or <Module.function>",
          meta,
          state
        )

      _ ->
        raise_syntax_error!("invalid component <#{name}>. Expected <Module.function>", meta, state)
    end
  end

  defp pop_let(attrs, state) do
    case List.keytake(attrs, ":let", 0) do
      {{":let", {:expr, _, _} = expr, attr_meta}, rest} ->
        {{parse_expr!(expr, state), attr_meta}, rest}

      {{":let", _value, attr_meta}, _rest} ->
        raise_syntax_error!(":let must be a pattern between {...}", attr_meta, state)

      nil ->
        {nil, attrs}
    end
  end

  # Splits attributes into {...} spreads and {atom, value_ast} pairs
  defp component_attrs(attrs, what, state) do
    Enum.reduce(Enum.reverse(attrs), {[], []}, fn
      {:root, {:expr, _, _} = expr, _meta}, {roots, pairs} ->
        {[quote(do: Map.new(unquote(parse_expr!(expr, state)))) | roots], pairs}

      {":" <> _ = special, _value, attr_meta}, _acc ->
        raise_syntax_error!("unsupported attribute #{special} in #{what}", attr_meta, state)

      {attr, {:expr, _, _} = expr, _meta}, {roots, pairs} ->
        {roots, [{String.to_atom(attr), parse_expr!(expr, state)} | pairs]}

      {attr, {:string, value, _}, _meta}, {roots, pairs} ->
        {roots, [{String.to_atom(attr), value} | pairs]}

      {attr, nil, _meta}, {roots, pairs} ->
        {roots, [{String.to_atom(attr), true} | pairs]}
    end)
  end

  defp merge_assigns(roots, pairs) do
    Enum.reduce(roots ++ [{:%{}, [], pairs}], fn map, acc -> quote(do: Map.merge(unquote(acc), unquote(map))) end)
  end

  # The inner block (non-slot children) and the named slots of a component
  defp slot_assigns(children, let, substate, state) do
    {slots, inner} = Enum.split_with(children, &slot?/1)
    inner_block = [{:inner_block, [slot_entry(:inner_block, [], let, inner, substate, state)]}]

    named =
      slots
      |> Enum.group_by(&slot_name/1)
      |> Enum.sort_by(fn {_name, [first | _]} -> slot_position(children, first) end)
      |> Enum.map(fn {name, entries} ->
        lists = Enum.map(entries, &slot_entries(&1, substate, state))
        {String.to_atom(name), quote(do: List.flatten(unquote(lists)))}
      end)

    inner_block ++ named
  end

  defp slot?({:block, :slot, _, _, _, _, _}), do: true
  defp slot?({:self_close, :slot, _, _, _}), do: true
  defp slot?(_node), do: false

  defp slot_name({_, :slot, name, _, _, _, _}), do: name
  defp slot_name({_, :slot, name, _, _}), do: name

  defp slot_position(children, slot), do: Enum.find_index(children, &(&1 == slot))

  # A list of entries for one <:slot> tag (more than one with :for, none with a false :if)
  defp slot_entries(node, substate, state) do
    {name, attrs, children, meta} =
      case node do
        {:block, :slot, name, attrs, children, meta, _close} -> {name, attrs, children, meta}
        {:self_close, :slot, name, attrs, meta} -> {name, attrs, nil, meta}
      end

    {special, attrs} = pop_special_attrs!(attrs, state)
    {let, attrs} = pop_let(attrs, state)

    if let && children == nil do
      raise_syntax_error!("cannot use :let on a slot without inner content", elem(let, 1), state)
    end

    {roots, pairs} = component_attrs(attrs, "slot <:#{name}>", state)
    entry = slot_entry(String.to_atom(name), {roots, pairs}, let, children, substate, state)

    case special do
      [] -> [entry]
      special -> special_slot_expr(special, entry, meta)
    end
  end

  defp slot_entry(name, attrs, let, children, substate, state) do
    inner_block =
      case children do
        nil ->
          nil

        children ->
          inner_ast = children |> handle_node(@engine.handle_begin(substate), state) |> @engine.handle_end()

          case let do
            nil ->
              quote(do: fn _argument -> unquote(inner_ast) end)

            # A variable always matches, so it doesn't need the catch-all clause
            {{var, _, context} = pattern, _meta} when is_atom(var) and is_atom(context) ->
              quote(do: fn unquote(pattern) -> unquote(inner_ast) end)

            {pattern, _meta} ->
              quote do
                fn
                  unquote(pattern) -> unquote(inner_ast)
                  other -> MjmlEEx.Component.__unmatched_let__!(unquote(Macro.to_string(pattern)), other)
                end
              end
          end
      end

    {roots, pairs} =
      case attrs do
        [] -> {[], []}
        attrs -> attrs
      end

    merge_assigns(roots, [{:__slot__, name}, {:inner_block, inner_block} | pairs])
  end

  defp special_slot_expr(special, entry, meta) do
    case {special[:for], special[:if]} do
      {nil, if_ast} -> quote(line: meta.line, do: if(unquote(if_ast), do: [unquote(entry)], else: []))
      {for_ast, nil} -> quote(line: meta.line, do: for(unquote(for_ast), do: unquote(entry)))
      {for_ast, if_ast} -> quote(line: meta.line, do: for(unquote(for_ast), unquote(if_ast), do: unquote(entry)))
    end
  end

  ## Tags and attributes

  defp handle_tag_and_attrs(name, attrs, suffix, substate, state) do
    validate_attrs!(attrs, state)
    substate = @engine.handle_text(substate, [], "<#{name}")

    substate =
      attrs
      |> Enum.reject(fn {attr, _value, _meta} -> attr in Tags.mjml_eex_attributes() end)
      |> Enum.reduce(substate, fn
        {:root, {:expr, _, _} = expr, attr_meta}, substate ->
          location = location(attr_meta, state)
          ast = quote(do: Runtime.attributes(unquote(name), unquote(parse_expr!(expr, state)), unquote(location)))
          @engine.handle_expr(substate, "=", ast)

        {attr, {:expr, _, _} = expr, attr_meta}, substate ->
          location = location(attr_meta, state)

          ast =
            quote(
              do: Runtime.attribute(unquote(name), unquote(attr), unquote(parse_expr!(expr, state)), unquote(location))
            )

          @engine.handle_expr(substate, "=", ast)

        {attr, {:string, value, %{delimiter: delimiter}}, _attr_meta}, substate ->
          @engine.handle_text(substate, [], " #{attr}=#{<<delimiter>>}#{value}#{<<delimiter>>}")

        {attr, nil, _attr_meta}, substate ->
          @engine.handle_text(substate, [], " #{attr}")
      end)

    @engine.handle_text(substate, [], suffix)
  end

  defp validate_attrs!(attrs, state) do
    Enum.each(attrs, fn
      {special, {:expr, _, _}, _meta} when special in [":if", ":for"] ->
        :ok

      {special, _value, meta} when special in [":if", ":for"] ->
        raise_syntax_error!("#{special} must be an expression between {...}", meta, state)

      {":" <> name, _value, meta} ->
        raise_syntax_error!("unsupported attribute :#{name} in tags", meta, state)

      # These change how the template is parsed, so they can't depend on a runtime value
      {name, {:expr, _, _}, meta} when is_binary(name) ->
        if name in Tags.mjml_eex_attributes() do
          raise_syntax_error!(
            "#{name} can't be an expression. Give it without a value, as in <mj-raw #{name}>",
            meta,
            state
          )
        end

      _attr ->
        :ok
    end)
  end

  ## :if and :for

  defp with_special_attrs(attrs, meta, substate, state, fun) do
    case pop_special_attrs!(attrs, state) do
      {[], attrs} ->
        fun.(attrs, substate)

      {special, attrs} ->
        inner_ast = attrs |> fun.(@engine.handle_begin(substate)) |> @engine.handle_end()
        @engine.handle_expr(substate, "=", special_expr(special, inner_ast, meta))
    end
  end

  defp pop_special_attrs!(attrs, state) do
    Enum.reduce([for: ":for", if: ":if"], {[], attrs}, fn {key, name}, {special, attrs} ->
      case List.keytake(attrs, name, 0) do
        {{^name, {:expr, _, _} = expr, attr_meta}, rest} ->
          if duplicate = List.keyfind(rest, name, 0) do
            {_, _, duplicate_meta} = duplicate

            raise_syntax_error!(
              "cannot define multiple #{name} attributes. Another #{name} has already been defined at line #{attr_meta.line}",
              duplicate_meta,
              state
            )
          end

          ast = parse_expr!(expr, state)

          if key == :for and not match?({:<-, _, [_, _]}, ast) do
            raise_syntax_error!(
              ":for must be a generator expression (pattern <- enumerable) between {...}",
              attr_meta,
              state
            )
          end

          {[{key, ast} | special], rest}

        {{^name, _value, attr_meta}, _rest} ->
          raise_syntax_error!("#{name} must be an expression between {...}", attr_meta, state)

        nil ->
          {special, attrs}
      end
    end)
  end

  # Lists can hold rendered templates (see Runtime.to_safe/1)
  defp to_safe(ast), do: quote(do: Runtime.to_safe(unquote(ast)))

  defp special_expr(special, inner_ast, meta) do
    case {special[:for], special[:if]} do
      {nil, if_ast} -> quote(line: meta.line, do: if(unquote(if_ast), do: unquote(inner_ast)))
      {for_ast, nil} -> quote(line: meta.line, do: for(unquote(for_ast), do: unquote(inner_ast)))
      {for_ast, if_ast} -> quote(line: meta.line, do: for(unquote(for_ast), unquote(if_ast), do: unquote(inner_ast)))
    end
  end

  ## Helpers

  # Where a dynamic attribute is, and the template's levels for the rules that runtime
  # validation checks
  defp location(%{line: line, column: column} = meta, state) do
    levels = Map.take(state.levels, Runtime.validated_rules())
    Macro.escape({file(meta, state), line, column, levels})
  end

  defp parse_expr!({:expr, value, meta}, state), do: quoted!(value, meta, state)

  # Parses an Elixir expression of the template. Expressions from included files carry their
  # file in the AST (like `quote location: :keep`), so that compiler warnings and errors in them
  # point to that file rather than to the template that includes it.
  defp quoted!(expr, %{line: line, column: column} = meta, state, opts \\ []) do
    file = file(meta, state)
    ast = Code.string_to_quoted!(expr, Keyword.merge([line: line, column: column, columns: true, file: file], opts))
    if file == state.file, do: ast, else: keep_file(ast, file)
  end

  defp keep_file(ast, file) do
    Macro.prewalk(ast, fn
      {form, meta, args} when is_list(meta) ->
        case Keyword.fetch(meta, :line) do
          {:ok, line} -> {form, Keyword.put(meta, :keep, {file, line}), args}
          :error -> {form, meta, args}
        end

      other ->
        other
    end)
  end

  # Nodes from an included file carry that file
  defp file(%{file: file}, _state) when is_binary(file), do: file
  defp file(_meta, state), do: state.file

  defp all_spaces?(children) do
    Enum.all?(children, fn
      {:eex_comment, _text, _meta} -> true
      {:text, text, _meta} -> String.trim_leading(text) == ""
      _node -> false
    end)
  end

  defp stab_clause?(expr), do: expr |> String.trim_trailing() |> String.ends_with?("->")

  defp insert_quoted({:__EEX__, _, [key]}, quoted) do
    {^key, value} = List.keyfind(quoted, key, 0)
    value
  end

  defp insert_quoted({left, meta, right}, quoted), do: {insert_quoted(left, quoted), meta, insert_quoted(right, quoted)}
  defp insert_quoted({left, right}, quoted), do: {insert_quoted(left, quoted), insert_quoted(right, quoted)}
  defp insert_quoted(list, quoted) when is_list(list), do: Enum.map(list, &insert_quoted(&1, quoted))
  defp insert_quoted(other, _quoted), do: other

  defp raise_syntax_error!(message, meta, state) do
    file = file(meta, state)

    # A snippet of the included file the node comes from, which starts at line 1
    {source, indentation} =
      if file == state.file,
        do: {state.source, state.indentation},
        else: {File.read!(file), 0}

    raise ParseError,
      line: meta.line,
      column: meta.column,
      file: file,
      description: message <> ParseError.code_snippet(source, meta, indentation)
  end
end
