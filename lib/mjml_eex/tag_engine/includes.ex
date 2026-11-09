defmodule MjmlEEx.TagEngine.Includes do
  @moduledoc false

  # Expands <mj-include> tags at compile time, following MJML's parser
  # (mjml-parser-xml's handleInclude and handleCssHtmlInclude):
  #
  #   * Paths are relative to the file that contains the mj-include.
  #   * type="html" becomes an mj-raw with the file's content.
  #   * type="css" becomes an mj-style (with inline="inline" for css-inline="inline") that
  #     is added to the document's mj-head.
  #   * Otherwise the file is MJML. If it contains <mjml>, its mj-body children replace the
  #     mj-include and its mj-head children are added to the document's mj-head (which is
  #     created if needed, after the other children, as MJML does). Otherwise its content
  #     replaces the mj-include as it is.
  #   * Included .meex files are templates (they can use {...} and EEx); other files are
  #     plain MJML. Includes can be nested, but not circular.
  #
  # Nodes from an included file carry `file:` in their meta, so validation errors point
  # into that file.

  alias MjmlEEx.ParseError
  alias MjmlEEx.TagEngine.Parser

  @doc false
  # Returns {nodes, included_files}
  @spec expand([tuple()], String.t()) :: {[tuple()], [String.t()]}
  def expand(nodes, file) do
    if contains_include?(nodes) do
      state = %{files: [], head: [], stack: [Path.expand(file)]}
      {nodes, state} = expand_nodes(nodes, Path.dirname(file), file, state)
      nodes = add_to_head(nodes, Enum.reverse(state.head), file)
      {nodes, Enum.reverse(state.files)}
    else
      {nodes, []}
    end
  end

  defp contains_include?(nodes) do
    Enum.any?(nodes, fn
      {:self_close, :tag, "mj-include", _, _} -> true
      {:block, :tag, "mj-include", _, _, _, _} -> true
      {:block, _, _, _, children, _, _} -> contains_include?(children)
      {:eex_block, _, clauses, _} -> Enum.any?(clauses, fn {children, _, _} -> contains_include?(children) end)
      _ -> false
    end)
  end

  defp expand_nodes(nodes, dir, file, state) do
    Enum.flat_map_reduce(nodes, state, fn node, state -> expand_node(node, dir, file, state) end)
  end

  defp expand_node({:self_close, :tag, "mj-include", attrs, meta}, dir, file, state),
    do: include(attrs, meta, dir, file, state)

  defp expand_node({:block, :tag, "mj-include", attrs, _children, meta, _close}, dir, file, state),
    do: include(attrs, meta, dir, file, state)

  defp expand_node({:block, type, name, attrs, children, meta, close}, dir, file, state) do
    {children, state} = expand_nodes(children, dir, file, state)
    {[{:block, type, name, attrs, children, meta, close}], state}
  end

  defp expand_node({:eex_block, expr, clauses, meta}, dir, file, state) do
    {clauses, state} =
      Enum.map_reduce(clauses, state, fn {children, clause, clause_meta}, state ->
        {children, state} = expand_nodes(children, dir, file, state)
        {{children, clause, clause_meta}, state}
      end)

    {[{:eex_block, expr, clauses, meta}], state}
  end

  defp expand_node(node, _dir, _file, state), do: {[node], state}

  defp include(attrs, meta, dir, file, state) do
    file = Map.get(meta, :file, file)

    # The include is replaced by the file's content when the template compiles, so it can't
    # be conditional or repeated itself
    with {":" <> _ = special, _value, attr_meta} <- List.keyfind(attrs, ":if", 0) || List.keyfind(attrs, ":for", 0) do
      error!(
        "#{special} can't be used on mj-include, which is expanded when the template compiles. " <>
          "Put the mj-include in an EEx block instead, such as <%= if ... do %>...<% end %>",
        attr_meta,
        file
      )
    end

    path = attr!(attrs, "path", meta, file) || error!("mj-include requires a path attribute", meta, file)
    type = attr!(attrs, "type", meta, file) || "mjml"
    included = path |> String.replace_prefix("file://", "") |> Path.expand(dir)

    if included in state.stack do
      error!("mj-include of #{path} is circular", meta, file)
    end

    content =
      case File.read(included) do
        {:ok, content} ->
          String.trim_leading(content, "\uFEFF")

        {:error, reason} ->
          error!(
            "mj-include can't read #{path} (#{Path.relative_to_cwd(included)}): #{:file.format_error(reason)}",
            meta,
            file
          )
      end

    state = %{state | files: [included | state.files]}

    case type do
      "html" ->
        {[element("mj-raw", [], content, meta)], state}

      "css" ->
        inline =
          if attr!(attrs, "css-inline", meta, file) == "inline",
            do: [{"inline", {:string, "inline", %{delimiter: ?"}}, meta}],
            else: []

        {[], %{state | head: [element("mj-style", inline, content, meta) | state.head]}}

      _mjml ->
        include_mjml(content, included, meta, state)
    end
  end

  defp include_mjml(content, included, meta, state) do
    interpolation = Path.extname(included) == ".meex"

    nodes =
      content
      |> Parser.parse!(file: included, interpolation: interpolation, trim_eex: false, strip_eex_comments: true)
      |> mark_file(included)

    state = %{state | stack: [included | state.stack]}

    {nodes, state} =
      if String.contains?(content, "<mjml>") do
        root =
          Enum.find(nodes, &match?({:block, :tag, "mjml", _, _, _, _}, &1)) ||
            error!("can't find the <mjml> root of #{included}", meta, included)

        {:block, :tag, "mjml", _, children, _, _} = root
        {body, state} = children |> child_nodes("mj-body") |> expand_nodes(Path.dirname(included), included, state)
        {head, state} = children |> child_nodes("mj-head") |> expand_nodes(Path.dirname(included), included, state)
        {body, %{state | head: Enum.reverse(head) ++ state.head}}
      else
        expand_nodes(nodes, Path.dirname(included), included, state)
      end

    {nodes, %{state | stack: tl(state.stack)}}
  end

  defp child_nodes(children, tag) do
    Enum.flat_map(children, fn
      {:block, :tag, ^tag, _, nodes, _, _} -> nodes
      _ -> []
    end)
  end

  # Adds the collected head nodes to the document's mj-head, creating it if needed
  defp add_to_head(nodes, [], _file), do: nodes

  defp add_to_head(nodes, head, file) do
    case Enum.split_with(nodes, &match?({:block, :tag, "mjml", _, _, _, _}, &1)) do
      {[], _} ->
        [first | _] = head

        error!(
          "type=\"css\" includes and included mj-head content need a whole document with an <mjml> root",
          node_meta(first),
          file
        )

      _ ->
        Enum.map(nodes, fn
          {:block, :tag, "mjml", attrs, children, meta, close} ->
            {:block, :tag, "mjml", attrs, put_head(children, head, meta), meta, close}

          node ->
            node
        end)
    end
  end

  defp put_head(children, head, meta) do
    if Enum.any?(children, &match?({:block, :tag, "mj-head", _, _, _, _}, &1)) do
      Enum.map(children, fn
        {:block, :tag, "mj-head", attrs, nodes, head_meta, close} ->
          {:block, :tag, "mj-head", attrs, nodes ++ head, head_meta, close}

        node ->
          node
      end)
    else
      # Like MJML, a created mj-head goes after the existing children
      children ++ [{:block, :tag, "mj-head", [], head, meta, meta}]
    end
  end

  defp node_meta({:block, _, _, _, _, meta, _}), do: meta
  defp node_meta({:self_close, _, _, _, meta}), do: meta
  defp node_meta(_node), do: %{line: 1, column: 1}

  defp element(name, attrs, content, meta) do
    meta = Map.merge(meta, %{tag_name: name, special: []})
    {:block, :tag, name, attrs, [{:text, content, Map.take(meta, [:line, :column, :file])}], meta, meta}
  end

  defp attr!(attrs, name, meta, file) do
    case List.keyfind(attrs, name, 0) do
      nil ->
        nil

      {_, {:string, value, _}, _} ->
        value

      {_, nil, _} ->
        ""

      {_, _expr, _} ->
        error!("the #{name} of an mj-include must be a literal string, so it can be read at compile time", meta, file)
    end
  end

  @doc false
  # Records the file nodes come from in their meta (and their attributes' meta)
  def mark_file(nodes, file) do
    Enum.map(nodes, fn
      {:block, type, name, attrs, children, meta, close} ->
        {:block, type, name, mark_attrs(attrs, file), mark_file(children, file), Map.put(meta, :file, file), close}

      {:self_close, type, name, attrs, meta} ->
        {:self_close, type, name, mark_attrs(attrs, file), Map.put(meta, :file, file)}

      {:eex_block, expr, clauses, meta} ->
        clauses =
          Enum.map(clauses, fn {children, clause, clause_meta} ->
            {mark_file(children, file), clause, Map.put(clause_meta, :file, file)}
          end)

        {:eex_block, expr, clauses, Map.put(meta, :file, file)}

      # :text, :body_expr, :eex and :eex_comment
      {type, content, meta} when is_map(meta) ->
        {type, content, Map.put(meta, :file, file)}

      node ->
        node
    end)
  end

  defp mark_attrs(attrs, file) do
    Enum.map(attrs, fn
      {name, {:expr, value, value_meta}, meta} ->
        {name, {:expr, value, Map.put(value_meta, :file, file)}, Map.put(meta, :file, file)}

      {name, value, meta} ->
        {name, value, Map.put(meta, :file, file)}
    end)
  end

  defp error!(message, meta, file) do
    raise ParseError, file: file, line: meta.line, column: meta.column, description: message
  end
end
