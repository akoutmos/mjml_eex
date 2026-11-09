# Forked from Phoenix.LiveView.TagEngine.Parser in Phoenix LiveView v1.2.12
# (lib/phoenix_live_view/tag_engine/parser.ex, https://github.com/phoenixframework/phoenix_live_view,
# commit 83ab190). Phoenix LiveView is MIT licensed: Copyright (c) 2018 Chris McCord.
#
# Changes from upstream:
#
#   * Macro components and directives are removed. parse/2 returns {:ok, nodes}.
#   * There is no tag handler (see MjmlEEx.TagEngine.Tags).
#   * `interpolation: false` (for plain MJML) skips EEx and `{...}` entirely.
#   * parse/2 also returns tokenizer errors as {:error, line, column, message}.
#   * Text nodes keep their start `line` and `column`, and EEx comments are
#     {:eex_comment, text, meta} so that every node has a location.
#   * EEx blocks that are never closed, or that a close tag cuts across, are syntax errors
#     instead of crashes.
#   * Invalid UTF-8 is a syntax error.
defmodule MjmlEEx.TagEngine.Parser do
  @moduledoc false

  @type tag_node() :: text() | comment() | block() | self_close() | expression()
  @type text() :: {:text, binary(), meta()}
  @type comment() :: {:eex_comment, binary(), meta()}
  @type block() :: {:block, atom(), binary(), list(attr()), list(tag_node()), meta(), meta()}
  @type self_close() :: {:self_close, atom(), binary(), list(attr()), meta()}
  @type expression() ::
          {:body_expr, binary(), meta()}
          | {:eex, binary(), meta()}
          | {:eex_block, binary(), list(eex_clause()), meta()}
  @type eex_clause() :: {list(tag_node()), binary(), meta()}
  @type attr :: {:root | binary(), attr_value(), meta()}
  @type attr_value :: {:expr, binary(), meta()} | {:string, binary(), meta()}
  @type meta() :: map()

  alias MjmlEEx.ParseError
  alias MjmlEEx.TagEngine.{Tags, Tokenizer}

  defguardp is_tag_open(tag_type) when tag_type not in [:close, :eex]

  @doc false
  def parse(source, opts \\ []) do
    prune_text_after_slots = Keyword.get(opts, :prune_text_after_slots, true)
    process_buffer = Keyword.get(opts, :process_buffer)

    source
    |> tokenize(opts)
    |> to_tree([], [], %{
      prune_text_after_slots: prune_text_after_slots,
      process_buffer: process_buffer
    })
  rescue
    error in ParseError ->
      {:error, error.line, error.column, error.description}
  end

  @doc false
  def parse!(source, opts \\ []) do
    case parse(source, opts) do
      {:ok, nodes} ->
        nodes

      {:error, line, column, message} ->
        raise ParseError,
          line: line,
          column: column,
          file: opts[:file] || "nofile",
          description: message <> code_snippet_unless_present(message, source, line, column, opts)
    end
  end

  # Tokenizer errors already carry a code snippet
  defp code_snippet_unless_present(message, source, line, column, opts) do
    if String.contains?(message, "\n") and String.contains?(message, " | ") do
      ""
    else
      source
      |> ParseError.snippet_source(Keyword.get(opts, :line, 1))
      |> ParseError.code_snippet(%{line: line, column: column}, opts[:indentation] || 0)
    end
  end

  # Tokenize contents using EEx.tokenize and MjmlEEx.TagEngine.Tokenizer respectively.
  #
  # The following content:
  #
  # "<section>\n  <p><%= user.name %></p>\n  <%= if true do %> <p>this</p><% else %><p>that</p><% end %>\n</section>\n"
  #
  # Will be tokenized as:
  #
  # [
  #   {:tag, "section", [], %{column: 1, line: 1}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:tag, "p", [], %{column: 3, line: 2}},
  #   {:eex, :start_expr, "<%= user.name ></p>\n  <%= if true do %>", %{block?: true, column: 6, line: 1}},
  #   {:text, " ", %{column_end: 2, line_end: 1}},
  #   {:tag, "p", [], %{column: 2, line: 1}},
  #   {:text, "this", %{column_end: 12, line_end: 1}},
  #   {:close, :tag, "p", %{column: 12, line: 1}},
  #   {:eex, :middle_expr, "<% else %>", %{block?: false, column: 35, line: 2}},
  #   {:tag, "p", [], %{column: 1, line: 1}},
  #   {:text, "that", %{column_end: 14, line_end: 1}},
  #   {:close, :tag, "p", %{column: 14, line: 1}},
  #   {:eex, :end_expr, "<% end %>", %{block?: false, column: 62, line: 2}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {:close, :tag, "section", %{column: 1, line: 2}}
  # ]
  #
  @eex_expr [:start_expr, :expr, :end_expr, :middle_expr]

  @doc false
  def tokenize(source, opts) do
    file = Keyword.get(opts, :file, "nofile")
    indentation = Keyword.get(opts, :indentation, 0)
    trim_eex = Keyword.get(opts, :trim_eex, true)
    strip_eex_comments = Keyword.get(opts, :strip_eex_comments, false)
    interpolation = Keyword.get(opts, :interpolation, true)
    first_line = Keyword.get(opts, :line, 1)
    # Editors on Windows may start files with a byte order mark, which MJML and mrml ignore
    source = String.trim_leading(source, "\uFEFF")
    snippet_source = ParseError.snippet_source(source, first_line)

    ensure_valid_utf8!(source, file, indentation, first_line)

    # Plain MJML has no EEx, so the whole source is a single text node
    eex_nodes =
      if interpolation do
        case EEx.tokenize(source, Keyword.take(opts, [:line, :column, :indentation, :trim, :file])) do
          {:ok, eex_nodes} -> eex_nodes
          {:error, message, meta} -> raise_eex_error!(message, meta, snippet_source, file, indentation)
        end
      else
        [{:text, String.to_charlist(source), %{line: first_line, column: 1}}]
      end

    initial_cont = {:text, if(interpolation, do: :enabled, else: :disabled)}

    {tokens, cont} =
      Enum.reduce(
        eex_nodes,
        {[], initial_cont},
        &do_tokenize(&1, &2, snippet_source, %{
          file: file,
          indentation: indentation,
          trim_eex: trim_eex,
          strip_eex_comments: strip_eex_comments,
          interpolation: interpolation
        })
      )

    Tokenizer.finalize(tokens, file, cont, snippet_source, indentation)
  end

  defp do_tokenize({:text, text, meta}, {tokens, cont}, source, %{
         file: file,
         indentation: indentation,
         interpolation: interpolation
       }) do
    text = List.to_string(text)
    meta = [line: meta.line, column: meta.column]
    state = Tokenizer.init(indentation, file, source, interpolation)
    Tokenizer.tokenize(text, meta, tokens, cont, state)
  end

  defp do_tokenize({:comment, text, meta}, {tokens, cont}, _contents, opts) do
    if opts.strip_eex_comments do
      {tokens, cont}
    else
      {[{:eex_comment, List.to_string(text), meta} | tokens], cont}
    end
  end

  defp do_tokenize(
         {type, opt, expr, %{column: column, line: line}},
         {tokens, cont},
         _contents,
         opts
       )
       when type in @eex_expr do
    meta = %{opt: opt, line: line, column: column}

    {[{:eex, type, expr |> List.to_string() |> maybe_trim_eex(opts.trim_eex), meta} | tokens], cont}
  end

  defp do_tokenize(_node, acc, _contents, _opts) do
    acc
  end

  defp maybe_trim_eex(string, true), do: String.trim(string)
  defp maybe_trim_eex(string, _), do: string

  defp ensure_valid_utf8!(source, file, indentation, first_line) do
    case :unicode.characters_to_binary(source) do
      binary when is_binary(binary) ->
        :ok

      {_error, valid, _rest} ->
        lines = String.split(valid, "\n")
        meta = %{line: first_line + length(lines) - 1, column: String.length(List.last(lines)) + 1}

        raise_eex_error!(
          "invalid UTF-8 in template",
          meta,
          ParseError.snippet_source(valid, first_line),
          file,
          indentation
        )
    end
  end

  defp raise_eex_error!(message, meta, source, file, indentation) do
    raise ParseError,
      file: file,
      line: meta.line,
      column: meta.column,
      description: message <> ParseError.code_snippet(source, meta, indentation)
  end

  # Build an HTML Tree according to the tokens from the EEx and HTML tokenizers.
  #
  # This is a recursive algorithm that will build an HTML tree from a flat list of
  # tokens. For instance, given this input:
  #
  # [
  #   {:tag, "div", [], %{column: 1, line: 1}},
  #   {:tag, "h1", [], %{column: 6, line: 1}},
  #   {:text, "Hello", %{column_end: 15, line_end: 1}},
  #   {:close, :tag, "h1", %{column: 15, line: 1}},
  #   {:close, :tag, "div", %{column: 20, line: 1}},
  #   {:tag, "div", [], %{column: 1, line: 2}},
  #   {:tag, "h1", [], %{column: 6, line: 2}},
  #   {:text, "World", %{column_end: 15, line_end: 2}},
  #   {:close, :tag, "h1", %{column: 15, line: 2}},
  #   {:close, :tag, "div", %{column: 20, line: 2}}
  # ]
  #
  # The output will be:
  #
  # [
  #   {:block, :tag, "div", [],
  #    [{:block, :tag, "h1", [],
  #      [{:text, "Hello", %{...}}],
  #      %{line: 1, column: 6, ...},
  #      %{line: 1, column: 15, ...}}],
  #    %{line: 1, column: 1, ...},
  #    %{line: 1, column: 20, ...}},
  #   {:block, :tag, "div", [],
  #    [{:block, :tag, "h1", [],
  #      [{:text, "World", %{...}}],
  #      %{line: 2, column: 6, ...},
  #      %{line: 2, column: 15, ...}}],
  #    %{line: 2, column: 1, ...},
  #    %{line: 2, column: 20, ...}}
  # ]
  #
  # Note that a `:block` has been created so that its fifth argument is a list of
  # its nested content, followed by open_meta and close_meta.
  #
  # ### How does this algorithm work?
  #
  # As this is a recursive algorithm, it starts with an empty buffer and an empty
  # stack. The buffer will be accumulated until it finds a `{:tag, ..., ...}`.
  #
  # As soon as the `tag_open` arrives, a new buffer will be started and we move
  # the previous buffer to the stack along with the `tag_open`:
  #
  #   ```
  #   defp to_tree([{type, name, attrs, meta} | tokens], buffer, stack, state)
  #        when is_tag_open(type) do
  #     to_tree(tokens, [], [{type, name, attrs, meta, buffer} | stack], state)
  #   end
  #   ```
  #
  # Then, we start to populate the buffer again until a `{:close, :tag, ...}` arrives:
  #
  #   ```
  #   defp to_tree(
  #          [{:close, type, name, close_meta} | tokens],
  #          buffer,
  #          [{type, name, attrs, open_meta, upper_buffer} | stack],
  #          state
  #        ) do
  #     block = {:block, type, name, attrs, Enum.reverse(buffer), open_meta, close_meta}
  #     to_tree(tokens, [block | upper_buffer], stack)
  #   end
  #   ```
  #
  # In the snippet above, we build the `:block` tuple with the accumulated buffer,
  # putting the buffer accumulated before the tag open (upper_buffer) on top.
  #
  # We apply the same logic for `eex` expressions but, instead of `tag_open` and
  # `tag_close`, eex expressions use `start_expr`, `middle_expr` and `end_expr`.
  # The only real difference is that we also need to handle `middle_buffer`.
  #
  # So given this eex input:
  #
  # ```elixir
  # [
  #   {:eex, :start_expr, "if true do", %{column: 0, line: 0, opt: '='}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:eex, :expr, "\"Hello\"", %{column: 3, line: 1, opt: '='}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {:eex, :middle_expr, "else", %{column: 1, line: 2, opt: []}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:eex, :expr, "\"World\"", %{column: 3, line: 3, opt: '='}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {:eex, :end_expr, "end", %{column: 1, line: 4, opt: []}}
  # ]
  # ```
  #
  # The output will be:
  #
  # ```elixir
  # [
  #   {:eex_block, "if true do",
  #    [
  #      {[{:eex, "\"Hello\"", %{column: 3, line: 1, opt: '='}}], "else", %{line: 2, column: 1}},
  #      {[{:eex, "\"World\"", %{column: 3, line: 3, opt: '='}}], "end", %{line: 4, column: 1}}
  #    ], %{line: 0, column: 0, opt: '='}}
  # ]
  # ```
  defp to_tree([], buffer, [], _state) do
    {:ok, Enum.reverse(buffer)}
  end

  defp to_tree([], _buffer, [eex_block | _], _state) when elem(eex_block, 0) == :eex_block do
    {expr, meta} = eex_block_info(eex_block)
    message = "end of template reached without `<% end %>` for `<%= #{expr} %>`"
    {:error, meta.line, meta.column, message}
  end

  defp to_tree(
         [],
         _buffer,
         [{_type, _name, _, %{line: line, column: column} = meta, _} | _],
         _state
       ) do
    message = "end of template reached without closing tag for <#{meta.tag_name}>"
    {:error, line, column, message}
  end

  defp to_tree([{:text, text, meta} | tokens], buffer, stack, state) do
    # Preserve context for HTML comment handling in formatter
    text_meta = Map.take(meta, [:context, :line, :column])
    buffer = process_buffer([{:text, text, text_meta} | buffer], state)
    to_tree(tokens, buffer, stack, state)
  end

  defp to_tree([{:body_expr, value, meta} | tokens], buffer, stack, state) do
    buffer = process_buffer([{:body_expr, value, meta} | buffer], state)
    to_tree(tokens, buffer, stack, state)
  end

  # Self-closing slot - valid only as direct child of component
  defp to_tree(
         [{:slot, name, attrs, %{closing: _} = meta} | tokens],
         buffer,
         [{parent_type, _, _, _, _} | _] = stack,
         state
       )
       when parent_type in [:local_component, :remote_component] do
    meta = Map.put(meta, :special, extract_special_attrs(attrs))
    buffer = [{:self_close, :slot, name, attrs, meta} | buffer]
    tokens = if state.prune_text_after_slots, do: prune_text(tokens), else: tokens

    to_tree(tokens, buffer, stack, state)
  end

  # Self-closing slot - invalid context (not direct child of component)
  defp to_tree(
         [{:slot, name, _attrs, %{closing: _} = meta} | _tokens],
         _buffer,
         _stack,
         _state
       ) do
    %{line: line, column: column} = meta
    message = "invalid slot entry <:#{name}>. A slot entry must be a direct child of a component"
    {:error, line, column, message}
  end

  # Opening slot - valid only as direct child of component
  defp to_tree(
         [{:slot, name, attrs, meta} | tokens],
         buffer,
         [{parent_type, _, _, _, _} | _] = stack,
         state
       )
       when parent_type in [:local_component, :remote_component] do
    meta = Map.put(meta, :special, extract_special_attrs(attrs))
    to_tree(tokens, [], [{:slot, name, attrs, meta, buffer} | stack], state)
  end

  # Opening slot - invalid context (not direct child of component)
  defp to_tree([{:slot, name, _attrs, meta} | _tokens], _buffer, _stack, _state) do
    %{line: line, column: column} = meta
    message = "invalid slot entry <:#{name}>. A slot entry must be a direct child of a component"
    {:error, line, column, message}
  end

  # Closing a slot
  defp to_tree(
         [{:close, :slot, _name, close_meta} | tokens],
         reversed_buffer,
         [{:slot, tag_name, attrs, open_meta, upper_buffer} | stack],
         state
       ) do
    block = Enum.reverse(reversed_buffer)
    tag_block = {:block, :slot, tag_name, attrs, block, open_meta, close_meta}
    tokens = if state.prune_text_after_slots, do: prune_text(tokens), else: tokens
    to_tree(tokens, [tag_block | upper_buffer], stack, state)
  end

  # Self-closing tag or component
  defp to_tree([{type, name, attrs, %{closing: _} = meta} | tokens], buffer, stack, state)
       when is_tag_open(type) do
    meta = Map.put(meta, :special, extract_special_attrs(attrs))
    to_tree(tokens, [{:self_close, type, name, attrs, meta} | buffer], stack, state)
  end

  # Opening tag or component
  defp to_tree([{type, name, attrs, meta} | tokens], buffer, stack, state)
       when is_tag_open(type) do
    meta = Map.put(meta, :special, extract_special_attrs(attrs))
    to_tree(tokens, [], [{type, name, attrs, meta, buffer} | stack], state)
  end

  # Close tag that cuts across an open EEx block
  defp to_tree([{:close, _type, name, close_meta} | _tokens], _buffer, [eex_block | _], _state)
       when elem(eex_block, 0) == :eex_block do
    {expr, meta} = eex_block_info(eex_block)

    message =
      "unmatched closing tag </#{name}> inside `<%= #{expr} %>` (line #{meta.line}). " <>
        "Close the tag before the `<% end %>`, or open it inside the block"

    {:error, close_meta.line, close_meta.column, message}
  end

  # Matching close tag
  defp to_tree(
         [{:close, type, name, close_meta} | tokens],
         reversed_buffer,
         [{type, name, attrs, open_meta, upper_buffer} | stack],
         state
       ) do
    block = Enum.reverse(reversed_buffer)
    to_tree(tokens, [{:block, type, name, attrs, block, open_meta, close_meta} | upper_buffer], stack, state)
  end

  # Mismatched close tag
  defp to_tree(
         [{:close, _close_type, close_name, close_meta} | _tokens],
         _buffer,
         [{_open_type, open_name, _attrs, open_meta, _upper_buffer} | _stack],
         _state
       ) do
    %{line: line, column: column} = close_meta
    void_note = void_tag_note(close_name)

    message =
      "unmatched closing tag. Expected </#{open_name}> for <#{open_name}> at line #{open_meta.line}, got: </#{close_name}>#{void_note}"

    {:error, line, column, message}
  end

  # Orphaned close tag - no matching open tag on stack
  defp to_tree([{:close, _type, name, meta} | _tokens], _buffer, [], _state) do
    %{line: line, column: column} = meta
    void_note = void_tag_note(name)
    message = "missing opening tag for </#{name}>#{void_note}"
    {:error, line, column, message}
  end

  # EEx

  defp to_tree([{:eex_comment, text, meta} | tokens], buffer, stack, state) do
    to_tree(tokens, [{:eex_comment, text, meta} | buffer], stack, state)
  end

  defp to_tree([{:eex, :start_expr, expr, meta} | tokens], buffer, stack, state) do
    to_tree(tokens, [], [{:eex_block, expr, meta, buffer} | stack], state)
  end

  defp to_tree(
         [{:eex, :middle_expr, middle_expr, middle_meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack],
         state
       ) do
    middle_buffer = merge_middle_expr(middle_buffer, buffer, middle_expr, middle_meta)

    to_tree(
      tokens,
      [],
      [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack],
      state
    )
  end

  defp to_tree(
         [{:eex, :middle_expr, middle_expr, middle_meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer} | stack],
         state
       ) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr, middle_meta}]

    to_tree(
      tokens,
      [],
      [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack],
      state
    )
  end

  defp to_tree(
         [{:eex, :end_expr, end_expr, end_meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack],
         state
       ) do
    block = Enum.reverse([{Enum.reverse(buffer), end_expr, end_meta} | middle_buffer])
    to_tree(tokens, [{:eex_block, expr, block, meta} | upper_buffer], stack, state)
  end

  defp to_tree(
         [{:eex, :end_expr, end_expr, end_meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer} | stack],
         state
       ) do
    block = [{Enum.reverse(buffer), end_expr, end_meta}]
    to_tree(tokens, [{:eex_block, expr, block, meta} | upper_buffer], stack, state)
  end

  # end_expr reached but unclosed tag on stack (inside a do-block)
  defp to_tree(
         [{:eex, :end_expr, _end_expr, _end_meta} | _tokens],
         _buffer,
         [{_type, _name, _attrs, %{line: line, column: column} = meta, _upper_buffer} | _stack],
         _state
       ) do
    message = "end of do-block reached without closing tag for <#{meta.tag_name}>"
    {:error, line, column, message}
  end

  defp to_tree([{:eex, _type, expr, meta} | tokens], buffer, stack, state) do
    buffer = process_buffer([{:eex, expr, meta} | buffer], state)
    to_tree(tokens, buffer, stack, state)
  end

  defp eex_block_info({:eex_block, expr, meta, _upper_buffer}), do: {expr, meta}
  defp eex_block_info({:eex_block, expr, meta, _upper_buffer, _middle_buffer}), do: {expr, meta}

  defp merge_middle_expr(
         [{prev_buffer, prev_expr, prev_meta} | middle_buffer],
         buffer,
         middle_expr,
         middle_meta
       ) do
    if all_spaces?(buffer) and not stab_clause?(prev_expr) do
      [
        {prev_buffer, prev_expr <> rendered_spaces(buffer) <> middle_expr, prev_meta}
        | middle_buffer
      ]
    else
      [
        {Enum.reverse(buffer), middle_expr, middle_meta},
        {prev_buffer, prev_expr, prev_meta} | middle_buffer
      ]
    end
  end

  defp merge_middle_expr([], buffer, middle_expr, middle_meta) do
    [{Enum.reverse(buffer), middle_expr, middle_meta}]
  end

  defp rendered_spaces(buffer) do
    buffer
    |> Enum.reverse()
    |> Enum.map(fn {:text, text, _meta} -> text end)
    |> IO.iodata_to_binary()
  end

  defp all_spaces?(nodes) do
    Enum.all?(nodes, fn
      {:text, text, _meta} -> String.trim_leading(text) == ""
      _ -> false
    end)
  end

  defp stab_clause?(expr) do
    expr
    |> String.trim_trailing()
    |> String.ends_with?("->")
  end

  @special_attrs ~w(:if :for :key)
  defp extract_special_attrs(attrs) do
    for {name, _, _} <- attrs, name in @special_attrs, do: name
  end

  # Prune leading whitespace from the next text token (used after slots)
  defp prune_text([{:text, text, meta} | tokens]) do
    [{:text, String.trim_leading(text), meta} | tokens]
  end

  defp prune_text(tokens), do: tokens

  # Allow callers to hook into buffer processing (used by formatter for preserve mode propagation)
  defp process_buffer(buffer, %{process_buffer: fun}) when is_function(fun), do: fun.(buffer)
  defp process_buffer(buffer, _state), do: buffer

  defp void_tag_note(name) do
    if Tags.void?(name) do
      " (note <#{name}> is a void tag and cannot have any content)"
    else
      ""
    end
  end
end
