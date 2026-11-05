# Forked from Phoenix.LiveView.HTMLFormatter in Phoenix LiveView v1.2.12
# (lib/phoenix_live_view/html_formatter.ex, https://github.com/phoenixframework/phoenix_live_view, commit 83ab190).
# Phoenix LiveView is MIT licensed: Copyright (c) 2018 Chris McCord.
#
# Changes from upstream:
#
#   * Claims ~MJML and .meex, with a :mjml_line_length option.
#   * Uses the forked MjmlEEx.TagEngine.Parser (no tag handler or macro components).
#   * Preserves the content of MJML ending tags, mj-style, raw text mj-raw, style, script,
#     pre, textarea and tags with mjml-no-format (instead of phx-no-format).
#   * Writes empty MJML components as self-closing tags.
#   * :tag_formatters only applies to mj-style.
# The formatting logic is kept close to upstream to ease future syncs, so these Credo
# checks are disabled for this file rather than restructuring it:
# credo:disable-for-this-file Credo.Check.Readability.PreferImplicitTry
# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule MjmlEEx.Formatter do
  @moduledoc """
  Formats MJML EEx templates in `.meex` files and `~MJML` sigils.

  This is a `mix format` [plugin](https://hexdocs.pm/mix/Mix.Tasks.Format.html#module-plugins),
  ported from Phoenix LiveView's HEEx formatter, so templates are formatted the way HEEx
  templates are.

  ## Setup

  Add it as a plugin to your `.formatter.exs` and include the `.meex` extension in `inputs`:

  ```elixir
  [
    plugins: [MjmlEEx.Formatter],
    inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs,meex}"]
  ]
  ```

  If you also use `Phoenix.LiveView.HTMLFormatter`, list both plugins. Each one only formats
  its own sigils and file extensions.

  ## Options

    * `:line_length` - the maximum line length, 98 by default, like the Elixir formatter.

    * `:mjml_line_length` - a line length for MJML templates only.

    * `:migrate_eex_to_curly_interpolation` - rewrite single `<%= ... %>` expressions as
      `{...}`. Defaults to `true`.

    * `:attribute_formatters` - formatters for specific attributes, as for HEEx.

    * `:tag_formatters` - a formatter for `mj-style` content, such as a CSS formatter. See
      `MjmlEEx.Formatter.TagFormatter`.

  ## Formatting

  - MJML components that hold other components (`mjml`, `mj-body`, `mj-section`, `mj-column`
    and so on) get one child per line, indented.
  - Empty MJML components are written self-closing: `<mj-image src="..." />`.
  - Function components and slots are laid out as in HEEx: on their own line when there's
    whitespace around them, and kept next to text they touch, since a component can render
    into an ending tag, where whitespace shows.
  - `<%# ... %>` comments are written as `<%!-- ... --%>`.
  - When a tag's attributes don't fit on one line, each attribute goes on its own line. A tag
    whose attributes are already on separate lines keeps them that way. Attributes are never
    reordered.
  - Elixir code in `{...}`, `<%= ... %>` and attribute values is formatted with the Elixir
    formatter. Unlike HEEx, `attr={"text"}` isn't rewritten as `attr="text"`, since expression
    values are escaped and literal values aren't.
  - Comments and intentional blank lines are kept, as in HEEx.
  - Line endings are written as `\\n`, like the Elixir formatter does.

  mrml ignores whitespace between MJML components when it starts with a line break, but copies
  other whitespace (a space or tab between two tags on the same line) into the HTML. Since every
  component goes on its own line, formatting can remove such whitespace from the HTML. It sits
  between table markup and has no visible effect.

  The content of these tags is kept exactly as written, since mrml copies it into the email
  HTML, where whitespace can matter:

  - ending tags, whose content is HTML: `mj-text`, `mj-button`, `mj-table`, `mj-raw`,
    `mj-navbar-link`, `mj-social-element`, `mj-accordion-title`, `mj-accordion-text`,
    `mj-carousel-image`, `mj-title`, `mj-preview` and `mj-breakpoint`;
  - `mj-style` (unless a tag formatter is configured), and `style`, `script`, `pre` and
    `textarea`;
  - any tag with the `mjml-no-format` attribute. The attribute is removed when the template
    is compiled.

  Because that content is kept byte for byte, Elixir code inside it (`{@name}` in an
  `mj-text`) isn't formatted, and multi-line content keeps its indentation when the tag moves
  to a different nesting level.

  The content of function components and slots is formatted like HEEx content, since where it
  ends up (possibly inside an ending tag) is only known inside the component.

  Text placed directly inside a container component (`<mj-column>Hi<mj-text>...`) isn't valid
  MJML, and `MjmlEEx.validate/2` reports it; the formatter may change the whitespace around it.

  To skip a whole sigil, use the `noformat` modifier: `~MJML\"\"\"...\"\"\"noformat`.
  """

  require Logger

  alias MjmlEEx.Formatter.Algebra
  alias MjmlEEx.ParseError
  alias MjmlEEx.Spec.Generated
  alias MjmlEEx.TagEngine.{Parser, Tags}

  # MJML components whose content is HTML (ending tags)
  @ending_tags for {name, %{ending_tag: true}} <- Generated.components(), do: name

  # HTML tags whose content is kept as written
  @preserved_html_tags ~w(pre textarea style script)

  # Default line length to be used in case nothing is specified in the `.formatter.exs` options.
  @default_line_length 98

  @behaviour Mix.Tasks.Format

  @impl Mix.Tasks.Format
  def features(_opts) do
    [sigils: [:MJML], extensions: [".meex"]]
  end

  @impl Mix.Tasks.Format
  def format(source, opts) do
    if opts[:sigil] === :MJML and opts[:modifiers] === ~c"noformat" do
      source
    else
      source |> do_format(opts) |> unless_closing_delimiter(source, opts)
    end
  catch
    # Templates the formatter can't lay out safely are left as they are
    :unformattable -> source
  end

  defp do_format(source, opts) do
    line_length = opts[:mjml_line_length] || opts[:line_length] || @default_line_length

    # Like the Elixir formatter, write "\n" line endings. EEx drops <%# %> comments without a
    # token, so they're rewritten as <%!-- --%>, the syntax that replaced them.
    source =
      source
      |> String.replace("\r\n", "\n")
      |> then(&Regex.replace(~r/<%#(.*?)%>/s, &1, "<%!--\\1--%>"))

    newlines = :binary.matches(source, ["\r\n", "\n"])

    opts =
      Enum.reduce([:attribute_formatters, :tag_formatters], opts, fn type, opts ->
        Keyword.update(opts, type, %{}, fn formatters ->
          Enum.reduce(formatters, %{}, fn {attr, formatter}, formatters ->
            if Code.ensure_loaded?(formatter) do
              Map.put(formatters, to_string(attr), formatter)
            else
              Logger.error("module #{inspect(formatter)} is not loaded and could not be found")
              formatters
            end
          end)
        end)
      end)

    file = Keyword.get(opts, :file, "nofile")

    formatted =
      source
      |> Parser.parse(
        file: file,
        prune_text_after_slots: false,
        process_buffer: &process_buffer/1
      )
      |> case do
        {:ok, nodes} ->
          nodes
          |> transform_tree(source, newlines, opts)
          |> Algebra.build(opts)
          |> Inspect.Algebra.format(line_length)

        {:error, line, column, message} ->
          raise ParseError, line: line + line_offset(opts), column: column, file: file, description: message
      end

    # If the opening delimiter is a single character, such as ~MJML"...", or the formatted code is empty,
    # do not add trailing newline.
    newline =
      if match?(<<_>>, opts[:opening_delimiter]) or IO.iodata_length(formatted) == 0,
        do: [],
        else: ?\n

    IO.iodata_to_binary([formatted, newline])
  end

  # In a single-line sigil, such as ~MJML"<mj-image src='a.png' />", formatting can add the
  # closing delimiter (as a quote or a parenthesis), which would have to be escaped, so the
  # sigil is left as it is
  @closing %{"\"" => "\"", "'" => "'", "(" => ")", "[" => "]", "{" => "}", "<" => ">", "|" => "|", "/" => "/"}

  defp unless_closing_delimiter(formatted, source, opts) do
    with <<_>> = opening <- opts[:opening_delimiter],
         {:ok, closing} <- Map.fetch(@closing, opening),
         true <- count(formatted, closing) > count(source, closing) do
      source
    else
      _ -> formatted
    end
  end

  defp count(text, pattern), do: length(:binary.matches(text, pattern))

  # Lines in a sigil count from its first line, and a heredoc's content starts on the next one
  defp line_offset(opts) do
    case opts[:line] do
      line when is_integer(line) -> if opts[:opening_delimiter] in [~S("""), ~S(''')], do: line, else: line - 1
      _ -> 0
    end
  end

  # Buffer processing callback for Parser - handles preserve mode propagation and text metadata
  defp process_buffer([{:text, text, meta} | rest]) do
    rest = may_set_preserve_on_block(rest, text)

    meta =
      meta
      |> Map.put_new(:newlines_before_text, count_newlines_before_text(text))
      |> Map.put_new(:newlines_after_text, count_newlines_after_text(text))

    [{:text, text, meta} | rest]
  end

  defp process_buffer([{:body_expr, _, _} = node | rest]) do
    [node | set_preserve_on_block(rest)]
  end

  defp process_buffer([{:eex, _, _} = node | rest]) do
    [node | set_preserve_on_block(rest)]
  end

  defp process_buffer(buffer), do: buffer

  # In case the closing tag is immediately followed by non-whitespace text,
  # we want to set mode as preserve. MJML components always go on their own line,
  # so they're never preserved because of what follows them.
  defp may_set_preserve_on_block([node | _] = buffer, text) when elem(node, 0) == :block do
    if mjml_tag?(node), do: buffer, else: do_may_set_preserve_on_block(buffer, text)
  end

  defp may_set_preserve_on_block(buffer, text), do: do_may_set_preserve_on_block(buffer, text)

  defp do_may_set_preserve_on_block(
         [{:block, type, name, attrs, block, meta, close_meta} | rest],
         text
       ) do
    mode =
      if trim_leading_ascii(text) != "" and :binary.first(text) not in ~c"\s\t\n\r" do
        :preserve
      else
        Map.get(meta, :mode, :normal)
      end

    [{:block, type, name, attrs, block, Map.put(meta, :mode, mode), close_meta} | rest]
  end

  defp do_may_set_preserve_on_block(buffer, _text), do: buffer

  # Set preserve on block when it is immediately followed by interpolation, unless it's
  # an MJML component.
  defp set_preserve_on_block([node | _] = buffer) when elem(node, 0) == :block do
    if mjml_tag?(node), do: buffer, else: do_set_preserve_on_block(buffer)
  end

  defp set_preserve_on_block(buffer), do: do_set_preserve_on_block(buffer)

  defp do_set_preserve_on_block([{:block, type, name, attrs, block, meta, close_meta} | rest]) do
    [{:block, type, name, attrs, block, Map.put(meta, :mode, :preserve), close_meta} | rest]
  end

  defp do_set_preserve_on_block(buffer), do: buffer

  defp count_newlines_before_text(binary),
    do: count_newlines_until_text(binary, 0, 0, 1)

  defp count_newlines_after_text(binary),
    do: count_newlines_until_text(binary, 0, byte_size(binary) - 1, -1)

  defp count_newlines_until_text(binary, counter, pos, inc) do
    try do
      :binary.at(binary, pos)
    rescue
      _ -> counter
    else
      char when char in [?\s, ?\t] -> count_newlines_until_text(binary, counter, pos + inc, inc)
      ?\n -> count_newlines_until_text(binary, counter + 1, pos + inc, inc)
      _ -> counter
    end
  end

  defp leading_whitespace(binary) do
    binary_part(binary, 0, count_leading_whitespace(binary, 0))
  end

  defp count_leading_whitespace(<<char, rest::binary>>, count) when char in ~c"\s\t\n\r",
    do: count_leading_whitespace(rest, count + 1)

  defp count_leading_whitespace(_rest, count),
    do: count

  defp trailing_whitespace(binary) do
    trailing_whitespace(binary, byte_size(binary) - 1, 0)
  end

  defp trailing_whitespace(binary, pos, len) do
    try do
      :binary.at(binary, pos)
    rescue
      _ -> binary_part(binary, byte_size(binary) - len, len)
    else
      char when char in [?\s, ?\t, ?\n, ?\r] -> trailing_whitespace(binary, pos - 1, len + 1)
      _ -> binary_part(binary, byte_size(binary) - len, len)
    end
  end

  # Tree transformation - augments Parser output with formatter metadata
  defp transform_tree(nodes, source, newlines, opts) do
    state = %{source: {source, newlines}, opts: opts, tag_formatters: opts[:tag_formatters]}
    augment_nodes(nodes, state)
  end

  # Augment nodes with formatter-specific metadata
  defp augment_nodes(nodes, state) when is_list(nodes) do
    nodes
    |> reduce_html_comments([])
    |> drop_spaces_next_to_mjml_tags()
    |> Enum.map(&augment_node(&1, state))
  end

  # Spaces (without a newline) next to an MJML component are dropped: every MJML component
  # goes on its own line anyway. Whitespace with newlines is kept, since it records
  # intentional blank lines.
  defp drop_spaces_next_to_mjml_tags(nodes) do
    nodes
    |> Enum.with_index()
    |> Enum.reject(fn {node, index} ->
      spaces_only_text?(node) and
        ((index > 0 and mjml_tag?(Enum.at(nodes, index - 1))) or mjml_tag?(Enum.at(nodes, index + 1)))
    end)
    |> Enum.map(&elem(&1, 0))
  end

  defp spaces_only_text?({:text, text, _meta}), do: ascii_whitespace?(text) and not String.contains?(text, "\n")
  defp spaces_only_text?(_node), do: false

  # MJML components get their own line. Function components and slots are laid out like
  # HEEx's: they can render into an ending tag, where whitespace next to them matters
  defp mjml_tag?({:block, :tag, name, _, _, _, _}), do: Tags.mjml?(name)
  defp mjml_tag?({:self_close, :tag, name, _, _}), do: Tags.mjml?(name)
  defp mjml_tag?(_node), do: false

  # Group text nodes with :comment_start/:comment_end context into {:html_comment, block}
  defp reduce_html_comments([], acc), do: Enum.reverse(acc)

  # Single node that is both comment start and end
  defp reduce_html_comments([{:text, text, %{context: [:comment_start, :comment_end]} = meta} | rest], acc) do
    trimmed = trim_ascii(text)
    leading = leading_whitespace(text)
    trailing = trailing_whitespace(text)

    cond do
      # Text that also has other content, such as `there <!-- note -->`, stays text
      not (String.starts_with?(trimmed, "<!--") and String.ends_with?(trimmed, "-->")) ->
        reduce_html_comments(rest, [{:text, text, Map.delete(meta, :context)} | acc])

      # A comment that touches what's next to it, such as `{@a}<!-- c -->{@b}`, stays inline,
      # as whitespace next to it would show in the email
      leading == "" or trailing == "" ->
        comment = {:text, trimmed, %{mode: :preserve, newlines_before_text: 0, newlines_after_text: 0}}
        nodes = Enum.reject([whitespace_node(leading), comment, whitespace_node(trailing)], &is_nil/1)
        reduce_html_comments(rest, Enum.reverse(nodes, acc))

      true ->
        reduce_standalone_comment(text, rest, acc)
    end
  end

  # Text that leaves a comment open (its last marker opens one), such as `<!-- a <%= b %>`, or
  # `<!-- a --> <!-- b <%= c %>` - begin accumulating comment content
  defp reduce_html_comments([{:text, text, %{context: [_ | _] = context}} | rest], acc) do
    if List.last(context) == :comment_start do
      # An intentional blank line before the comment is kept
      acc = blank_line(leading_whitespace(text), acc)
      collect_comment(rest, [{:text, trim_leading_ascii(text), %{}}], acc)
    else
      reduce_html_comments(rest, [{:text, text, %{context: context}} | acc])
    end
  end

  # Regular node - pass through
  defp reduce_html_comments([node | rest], acc) do
    reduce_html_comments(rest, [node | acc])
  end

  defp whitespace_node(""), do: nil

  defp whitespace_node(text) do
    {:text, text,
     %{newlines_before_text: count_newlines_before_text(text), newlines_after_text: count_newlines_after_text(text)}}
  end

  defp reduce_standalone_comment(text, rest, acc) do
    # Split leading/trailing whitespace into separate text nodes when they
    # contain intentional blank lines (2+ newlines). This lets the normal
    # blank line handling in block_to_algebra produce clean empty lines
    # without trailing whitespace.
    leading = leading_whitespace(text)
    leading_newlines = count_newlines_before_text(leading)

    acc =
      if leading_newlines > 1 do
        meta = %{
          newlines_before_text: leading_newlines,
          newlines_after_text: count_newlines_after_text(leading)
        }

        [{:text, leading, meta} | acc]
      else
        acc
      end

    comment_meta = %{newlines_before_text: 0, newlines_after_text: 0}
    comment = {:html_comment, [{:text, trim_ascii(text), comment_meta}]}
    acc = [comment | acc]

    trailing = trailing_whitespace(text)
    trailing_newlines = count_newlines_before_text(trailing)

    acc =
      if trailing_newlines > 1 do
        meta = %{
          newlines_before_text: trailing_newlines,
          newlines_after_text: count_newlines_after_text(trailing)
        }

        [{:text, trailing, meta} | acc]
      else
        acc
      end

    reduce_html_comments(rest, acc)
  end

  # Text that closes the comment and opens another, such as `--> <!-- <%= b %>`: the
  # comments are kept together
  defp collect_comment([{:text, text, %{context: [:comment_end | _] = context}} | rest], comment_buffer, acc)
       when length(context) > 1 do
    if List.last(context) == :comment_start do
      collect_comment(rest, [{:text, text, %{}} | comment_buffer], acc)
    else
      close_comment(text, rest, comment_buffer, acc)
    end
  end

  # Collect comment content until we hit comment_end
  defp collect_comment([{:text, text, %{context: [:comment_end]}} | rest], comment_buffer, acc) do
    close_comment(text, rest, comment_buffer, acc)
  end

  # A comment that crosses the end of an EEx block, such as `<%= if @a do %><!-- <% end %> -->`,
  # can't be laid out, so the template is left as it is
  defp collect_comment([], _comment_buffer, _acc), do: throw(:unformattable)

  defp collect_comment([node | rest], comment_buffer, acc) do
    collect_comment(rest, [node | comment_buffer], acc)
  end

  defp close_comment(text, rest, comment_buffer, acc) do
    meta = %{
      newlines_before_text: count_newlines_before_text(text),
      newlines_after_text: count_newlines_after_text(text)
    }

    end_text = {:text, trim_trailing_ascii(text), meta}
    block = Enum.reverse([end_text | comment_buffer])
    comment = {:html_comment, block}
    reduce_html_comments(rest, blank_line(trailing_whitespace(text), [comment | acc]))
  end

  # Whitespace with an intentional blank line (2+ newlines) becomes its own text node, so
  # block_to_algebra keeps the blank line
  defp blank_line(whitespace, acc) do
    case count_newlines_before_text(whitespace) do
      newlines when newlines > 1 ->
        [
          {:text, whitespace,
           %{newlines_before_text: newlines, newlines_after_text: count_newlines_after_text(whitespace)}}
          | acc
        ]

      _ ->
        acc
    end
  end

  # Handle block tags - add mode and recursively augment children
  defp augment_node({:block, :tag, name, attrs, children, meta, close_meta}, state) do
    if empty_mjml_component?(name, children) do
      # Empty MJML components are written self-closing (D10)
      {:self_close, :tag, name, attrs, meta}
    else
      augment_block({:block, :tag, name, attrs, children, meta, close_meta}, state)
    end
  end

  defp augment_node({:block, _type, _name, _attrs, _children, _meta, _close_meta} = block, state) do
    augment_block(block, state)
  end

  # Recursively augment eex_block children
  defp augment_node({:eex_block, expr, blocks, meta}, state) do
    blocks =
      Enum.map(blocks, fn {children, clause, clause_meta} ->
        {augment_nodes(children, state), clause, clause_meta}
      end)

    {:eex_block, expr, blocks, meta}
  end

  # html_comment - recursively augment block content
  defp augment_node({:html_comment, block}, state) do
    {:html_comment, augment_nodes(block, state)}
  end

  # Pass through other node types
  defp augment_node(node, _state), do: node

  # With a tag formatter, mj-style is formatted, or kept as written when it returns :skip
  defp augment_block({:block, :tag, "mj-style", attrs, _children, meta, close_meta} = block, state)
       when is_map_key(state.tag_formatters, "mj-style") do
    if determine_mode("mj-style", attrs, meta, state) == :preserve do
      preserve_block(block, state)
    else
      content = content_from_source(state.source, meta.inner_location, close_meta.inner_location)

      case maybe_format_tag({:block, :tag, "mj-style", attrs, [{:text, content, %{}}], meta, close_meta}, state) do
        :skip -> preserve_block(block, state)
        formatted -> formatted
      end
    end
  end

  defp augment_block({:block, type, name, attrs, children, meta, close_meta}, state) do
    mode = determine_mode(name, attrs, meta, state)

    {children, meta} =
      if mode == :preserve do
        content =
          content_from_source(state.source, meta.inner_location, close_meta.inner_location)

        {[{:text, content, %{newlines_before_text: 0, newlines_after_text: 0}}], Map.put(meta, :mode, :preserve)}
      else
        {augment_nodes(children, state), Map.put(meta, :mode, :normal)}
      end

    {:block, type, name, attrs, children, meta, close_meta}
  end

  defp preserve_block({:block, type, name, attrs, _children, meta, close_meta}, state) do
    content = content_from_source(state.source, meta.inner_location, close_meta.inner_location)
    children = [{:text, content, %{newlines_before_text: 0, newlines_after_text: 0}}]
    {:block, type, name, attrs, children, Map.put(meta, :mode, :preserve), close_meta}
  end

  # Ending tags keep their (HTML) content, so only truly empty ones are self-closed.
  # Other MJML components are self-closed when they only hold whitespace.
  defp empty_mjml_component?(name, children) do
    Tags.mjml?(name) and
      (children == [] or (name not in @ending_tags and Enum.all?(children, &whitespace_text?/1)))
  end

  defp whitespace_text?({:text, text, _meta}), do: ascii_whitespace?(text)
  defp whitespace_text?(_node), do: false

  # Trimming only touches ASCII whitespace, since mrml renders other spaces (such as
  # U+00A0) as text
  defp trim_ascii(text), do: text |> trim_leading_ascii() |> trim_trailing_ascii()
  defp trim_leading_ascii(text), do: String.trim_leading(text, " ") |> drop_leading_ascii()
  defp trim_trailing_ascii(text), do: text |> String.reverse() |> trim_leading_ascii() |> String.reverse()

  defp drop_leading_ascii(<<char, rest::binary>>) when char in ~c" \t\n\r", do: drop_leading_ascii(rest)
  defp drop_leading_ascii(text), do: text

  # Only ASCII whitespace: mrml renders other spaces, such as U+00A0, as text
  defp ascii_whitespace?(<<char, rest::binary>>) when char in ~c" \t\n\r", do: ascii_whitespace?(rest)
  defp ascii_whitespace?(<<>>), do: true
  defp ascii_whitespace?(_text), do: false

  # Determine mode based on tag name, attributes, and existing meta
  defp determine_mode(tag_name, attrs, meta, state) do
    cond do
      Map.get(meta, :mode) == :preserve -> :preserve
      contains_special_attrs?(attrs) -> :preserve
      # mj-style is an ending tag too, but a tag formatter may format it
      tag_name == "mj-style" -> if is_map_key(state.tag_formatters, "mj-style"), do: :normal, else: :preserve
      tag_name in @ending_tags -> :preserve
      tag_name in @preserved_html_tags -> :preserve
      Tags.raw_text?(tag_name, attrs) -> :preserve
      true -> :normal
    end
  end

  defp contains_special_attrs?(attrs) do
    Enum.any?(attrs, fn
      {"contenteditable", {:string, "false", _meta}, _} -> false
      {"contenteditable", _v, _} -> true
      {attr, _v, _} -> attr == Tags.no_format_attribute()
      _ -> false
    end)
  end

  # Extract content from source between two locations
  defp content_from_source(
         {source, newlines},
         {line_start, column_start},
         {line_end, column_end}
       ) do
    lines = Enum.slice([{0, 0} | newlines], (line_start - 1)..(line_end - 1))
    [first_line | _] = lines
    [last_line | _] = Enum.reverse(lines)

    offset_start = line_byte_offset(source, first_line, column_start)
    offset_end = line_byte_offset(source, last_line, column_end)

    binary_part(source, offset_start, offset_end - offset_start)
  end

  defp line_byte_offset(source, {line_before, line_size}, column) do
    line_offset = line_before + line_size

    line_extra =
      source
      |> binary_part(line_offset, byte_size(source) - line_offset)
      |> codepoint_byte_size(column - 1)

    line_offset + line_extra
  end

  defp codepoint_byte_size(binary, count),
    do: codepoint_byte_size(binary, count, byte_size(binary))

  defp codepoint_byte_size(binary, 0, original_size), do: original_size - byte_size(binary)
  defp codepoint_byte_size(<<>>, _count, original_size), do: original_size

  defp codepoint_byte_size(<<_codepoint::utf8, rest::binary>>, count, original_size) do
    codepoint_byte_size(rest, count - 1, original_size)
  end

  defp maybe_format_tag(
         {:block, :tag, "mj-style" = name, attrs, [{:text, content, _meta}], meta, close_meta},
         state
       )
       when is_map_key(state.tag_formatters, name) do
    simple_attrs =
      for {key, value, _attr_meta}
          when (is_tuple(value) and elem(value, 0) == :string) or is_nil(value) <- attrs,
          into: %{} do
        case value do
          {:string, value, _meta} -> {key, value}
          nil -> {key, true}
        end
      end

    case state.tag_formatters[name].render_tag({name, simple_attrs, content}, state.opts) do
      :skip ->
        :skip

      {:ok, formatted_content} ->
        children = [{:text, formatted_content, %{newlines_before_text: 0, newlines_after_text: 0}}]
        {:block, :tag, name, attrs, children, Map.put(meta, :mode, :normal), close_meta}
    end
  end
end
