# Forked from Phoenix.LiveView.TagEngine.Tokenizer in Phoenix LiveView v1.2.12
# (lib/phoenix_live_view/tag_engine/tokenizer.ex, https://github.com/phoenixframework/phoenix_live_view,
# commit 83ab190). Phoenix LiveView is MIT licensed: Copyright (c) 2018 Chris McCord.
#
# Changes from upstream:
#
#   * Tags are classified by MjmlEEx.TagEngine.Tags instead of a tag handler.
#   * Raw text elements are `script`, `style`, `mj-style`, and `mj-raw` when it has the
#     `mjml-raw-text` attribute, instead of only `script` and `style`.
#   * The curly interpolation opt-out attribute is `mjml-no-curly-interpolation`.
#   * `interpolation: false` (for plain MJML) disables `{...}` in text, attribute
#     values and tags, and the missing attribute space warning.
#   * ParseError is the public MjmlEEx.ParseError.
#   * An unclosed comment that spans an EEx expression is reported at its real start.
#   * In plain mode every tag is an element (no components or slots).
#   * Close tags may have whitespace before `>` (`</mj-text >`), including raw text close tags.
#   * Text tokens also record where they start (`line` and `column`).
defmodule MjmlEEx.TagEngine.Tokenizer do
  @moduledoc false

  alias MjmlEEx.ParseError
  alias MjmlEEx.TagEngine.Tags

  @space_chars ~c"\s\t\f"
  @quote_chars ~c"\"'"
  @stop_chars ~c">/=\r\n" ++ @quote_chars ++ @space_chars

  @doc false
  def finalize(_tokens, file, {:comment, line, column}, source, indentation) do
    message = "expected closing `-->` for comment"
    meta = %{line: line, column: column}
    raise_syntax_error!(message, meta, %{source: source, file: file, indentation: indentation})
  end

  def finalize(tokens, _file, _cont, _source, _indentation) do
    tokens
    |> strip_text_token_fully()
    |> Enum.reverse()
    |> strip_text_token_fully()
  end

  @doc """
  Initiate the Tokenizer state.

  ### Params

  * `indentation` - An integer that indicates the current indentation.
  * `file` - Can be either a file or a string "nofile".
  * `source` - The contents of the file as binary to be tokenized.
  * `interpolation` - When `false`, `{...}` is never treated as an Elixir expression.
  """
  def init(indentation, file, source, interpolation \\ true) do
    %{
      file: file,
      column_offset: indentation + 1,
      braces: if(interpolation, do: :enabled, else: :disabled),
      interpolation: interpolation,
      context: [],
      text_start: nil,
      source: source,
      indentation: indentation
    }
  end

  @doc """
  Tokenize the given text according to the given params.

  ### Params

  * `text` - The content to be tokenized.
  * `meta` - A keyword list with `:line` and `:column`. Both must be integers.
  * `tokens` - A list of tokens.
  * `cont` - `{:text, braces}`, `{:raw_text, tag_name}` or `{:comment, line, column}`.
  * `state` - The tokenizer state that must be initiated by `Tokenizer.init/4`

  ### Examples

      iex> alias MjmlEEx.TagEngine.Tokenizer

      iex> state =
        Tokenizer.init(indent, file, [text: "<section><div/></section>"])

      iex> Tokenizer.tokenize(state)
      {[
         {:close, :tag, "section", %{column: 16, line: 1}},
         {:tag, "div", [], %{column: 10, line: 1, closing: :self}},
         {:tag, "section", [], %{column: 1, line: 1}}
       ], {:text, :enabled}}
  """
  def tokenize(text, meta, tokens, cont, state) do
    line = Keyword.get(meta, :line, 1)
    column = Keyword.get(meta, :column, 1)

    case cont do
      {:text, braces} ->
        handle_text(text, line, column, [], tokens, %{state | braces: braces})

      {:raw_text, name} ->
        handle_raw_text(text, name, line, column, [], tokens, state)

      {:comment, comment_line, comment_column} ->
        continue_comment(text, line, column, tokens, state, comment_line, comment_column)
    end
  end

  ## handle_text

  # Remember where each text token starts
  defp handle_text(text, line, column, [], acc, state) do
    do_handle_text(text, line, column, [], acc, %{state | text_start: {line, column}})
  end

  defp handle_text(text, line, column, buffer, acc, state) do
    do_handle_text(text, line, column, buffer, acc, state)
  end

  defp do_handle_text("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_text(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp do_handle_text("\n" <> rest, line, _column, buffer, acc, state) do
    handle_text(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp do_handle_text("<!doctype" <> rest, line, column, buffer, acc, state) do
    handle_doctype(rest, line, column + 9, ["<!doctype" | buffer], acc, state)
  end

  defp do_handle_text("<!DOCTYPE" <> rest, line, column, buffer, acc, state) do
    handle_doctype(rest, line, column + 9, ["<!DOCTYPE" | buffer], acc, state)
  end

  defp do_handle_text("<!--" <> rest, line, column, buffer, acc, state) do
    state = update_in(state.context, &[:comment_start | &1])
    handle_comment(rest, line, column + 4, ["<!--" | buffer], acc, state)
  end

  defp do_handle_text("</" <> rest, line, column, buffer, acc, state) do
    text_to_acc = text_to_acc(buffer, acc, line, column, state.context, state.text_start)
    handle_tag_close(rest, line, column + 2, text_to_acc, %{state | context: []})
  end

  defp do_handle_text("<" <> rest, line, column, buffer, acc, state) do
    text_to_acc = text_to_acc(buffer, acc, line, column, state.context, state.text_start)
    handle_tag_open(rest, line, column + 1, text_to_acc, %{state | context: []})
  end

  defp do_handle_text("{" <> rest, line, column, buffer, acc, %{braces: :enabled} = state) do
    text_to_acc = text_to_acc(buffer, acc, line, column, state.context, state.text_start)
    state = put_in(state.context, [])

    case handle_interpolation(rest, line, column + 1, [], 0, state) do
      {:ok, value, new_line, new_column, rest} ->
        acc = [{:body_expr, value, %{line: line, column: column}} | text_to_acc]
        handle_text(rest, new_line, new_column, [], acc, state)

      {:error, message} ->
        meta = %{line: line, column: column}
        raise_syntax_error!(message, meta, state)
    end
  end

  defp do_handle_text(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_text(rest, line, column + 1, [char_or_bin(c) | buffer], acc, state)
  end

  defp do_handle_text(<<>>, line, column, buffer, acc, state) do
    ok(text_to_acc(buffer, acc, line, column, state.context, state.text_start), {:text, state.braces})
  end

  ## handle_doctype

  defp handle_doctype(<<?>, rest::binary>>, line, column, buffer, acc, state) do
    handle_text(rest, line, column + 1, [?> | buffer], acc, state)
  end

  defp handle_doctype("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_doctype(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp handle_doctype("\n" <> rest, line, _column, buffer, acc, state) do
    handle_doctype(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp handle_doctype(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_doctype(rest, line, column + 1, [char_or_bin(c) | buffer], acc, state)
  end

  defp handle_doctype(<<>>, line, column, _buffer, _acc, state) do
    raise_syntax_error!(
      "unexpected end of string inside tag",
      %{line: line, column: column},
      state
    )
  end

  ## handle_raw_text (generalizes upstream's handle_script and handle_style)

  defp handle_raw_text(text, name, line, column, buffer, acc, state) do
    state = if buffer == [], do: %{state | text_start: {line, column}}, else: state

    case raw_text_close(text, "</" <> name) do
      {:ok, rest, close_length} ->
        acc = [
          {:close, :tag, name, %{line: line, column: column, inner_location: {line, column}}}
          | text_to_acc(buffer, acc, line, column, [], state.text_start)
        ]

        handle_text(rest, line, column + close_length, [], acc, state)

      :error ->
        do_handle_raw_text(text, name, line, column, buffer, acc, state)
    end
  end

  # Matches `</name>`, allowing spaces and tabs before the `>`
  defp raw_text_close(text, prefix) do
    if String.starts_with?(text, prefix) do
      text
      |> binary_part(byte_size(prefix), byte_size(text) - byte_size(prefix))
      |> skip_close_tag_space(String.length(prefix))
    else
      :error
    end
  end

  defp skip_close_tag_space(<<c, rest::binary>>, length) when c in @space_chars,
    do: skip_close_tag_space(rest, length + 1)

  defp skip_close_tag_space(">" <> rest, length), do: {:ok, rest, length + 1}
  defp skip_close_tag_space(_text, _length), do: :error

  defp do_handle_raw_text("\r\n" <> rest, name, line, _column, buffer, acc, state) do
    handle_raw_text(rest, name, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp do_handle_raw_text("\n" <> rest, name, line, _column, buffer, acc, state) do
    handle_raw_text(rest, name, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp do_handle_raw_text(<<c::utf8, rest::binary>>, name, line, column, buffer, acc, state) do
    handle_raw_text(rest, name, line, column + 1, [char_or_bin(c) | buffer], acc, state)
  end

  defp do_handle_raw_text(<<>>, name, line, column, buffer, acc, state) do
    ok(text_to_acc(buffer, acc, line, column, [], state.text_start), {:raw_text, name})
  end

  ## handle_comment

  # A comment that is still open after an EEx expression keeps its original start
  # location. (Upstream reports a location relative to the new text chunk, which can
  # produce a negative column.)
  defp continue_comment(text, line, column, tokens, state, comment_line, comment_column) do
    state = %{state | text_start: {line, column}}

    case handle_comment(text, line, column, [], tokens, state) do
      {acc, {:comment, _line, _column}} -> {acc, {:comment, comment_line, comment_column}}
      result -> result
    end
  end

  defp handle_comment(rest, line, column, buffer, acc, state) do
    case handle_comment(rest, line, column, buffer, state) do
      {:text, rest, line, column, buffer} ->
        state = update_in(state.context, &[:comment_end | &1])
        handle_text(rest, line, column, buffer, acc, state)

      {:ok, line_end, column_end, buffer} ->
        acc = text_to_acc(buffer, acc, line_end, column_end, state.context, state.text_start)
        # We do column - 4 to point to the opening <!--
        ok(acc, {:comment, line, column - 4})
    end
  end

  defp handle_comment("\r\n" <> rest, line, _column, buffer, state) do
    handle_comment(rest, line + 1, state.column_offset, ["\r\n" | buffer], state)
  end

  defp handle_comment("\n" <> rest, line, _column, buffer, state) do
    handle_comment(rest, line + 1, state.column_offset, ["\n" | buffer], state)
  end

  defp handle_comment("-->" <> rest, line, column, buffer, _state) do
    {:text, rest, line, column + 3, ["-->" | buffer]}
  end

  defp handle_comment(<<c::utf8, rest::binary>>, line, column, buffer, state) do
    handle_comment(rest, line, column + 1, [char_or_bin(c) | buffer], state)
  end

  defp handle_comment(<<>>, line, column, buffer, _state) do
    {:ok, line, column, buffer}
  end

  ## handle_tag_open

  defp handle_tag_open(text, line, column, acc, state) do
    case handle_tag_name(text, column, []) do
      {:ok, name, new_column, rest} ->
        meta = %{line: line, column: column - 1, inner_location: nil, tag_name: name}

        case classify_type(name, state) do
          {:error, message} ->
            raise_syntax_error!(message, %{line: line, column: column}, state)

          {type, name} ->
            acc = [{type, name, [], meta} | acc]
            handle_maybe_tag_open_end(rest, line, new_column, acc, state)
        end

      :error ->
        message =
          "expected tag name after <. If you meant to use < as part of a text, use &lt; instead"

        meta = %{line: line, column: column}

        raise_syntax_error!(message, meta, state)
    end
  end

  ## handle_tag_close

  defp handle_tag_close(text, line, column, acc, state) do
    case handle_tag_name(text, column, []) do
      {:ok, name, name_end_column, rest} ->
        case skip_close_tag_space(rest, 0) do
          {:ok, rest, close_length} ->
            meta = %{
              line: line,
              column: column - 2,
              inner_location: {line, column - 2},
              tag_name: name
            }

            case classify_type(name, state) do
              {:error, message} ->
                raise_syntax_error!(message, meta, state)

              {type, name} ->
                acc = [{:close, type, name, meta} | acc]
                handle_text(rest, line, name_end_column + close_length, [], acc, pop_braces(state))
            end

          :error ->
            message = "expected closing `>`"
            meta = %{line: line, column: name_end_column}
            raise_syntax_error!(message, meta, state)
        end

      :error ->
        message = "expected tag name after </"
        meta = %{line: line, column: column}
        raise_syntax_error!(message, meta, state)
    end
  end

  ## handle_tag_name

  defp handle_tag_name(<<c::utf8, _rest::binary>> = text, column, buffer)
       when c in @stop_chars do
    done_tag_name(text, column, buffer)
  end

  defp handle_tag_name(<<c::utf8, rest::binary>>, column, buffer) do
    handle_tag_name(rest, column + 1, [char_or_bin(c) | buffer])
  end

  defp handle_tag_name(<<>>, column, buffer) do
    done_tag_name(<<>>, column, buffer)
  end

  defp done_tag_name(_text, _column, []) do
    :error
  end

  defp done_tag_name(text, column, buffer) do
    {:ok, buffer_to_string(buffer), column, text}
  end

  ## handle_maybe_tag_open_end

  defp handle_maybe_tag_open_end("\r\n" <> rest, line, _column, acc, state) do
    handle_maybe_tag_open_end(rest, line + 1, state.column_offset, acc, state)
  end

  defp handle_maybe_tag_open_end("\n" <> rest, line, _column, acc, state) do
    handle_maybe_tag_open_end(rest, line + 1, state.column_offset, acc, state)
  end

  defp handle_maybe_tag_open_end(<<c::utf8, rest::binary>>, line, column, acc, state)
       when c in @space_chars do
    handle_maybe_tag_open_end(rest, line, column + 1, acc, state)
  end

  defp handle_maybe_tag_open_end("/>" <> rest, line, column, acc, state) do
    acc = normalize_tag(acc, line, column + 2, true, state)
    handle_text(rest, line, column + 2, [], acc, end_childless_tag(acc, state))
  end

  defp handle_maybe_tag_open_end(">" <> rest, line, column, acc, state) do
    case normalize_tag(acc, line, column + 1, false, state) do
      [{:tag, name, attrs, meta} | _] = acc ->
        cond do
          # Raw text has no interpolation and no closing tag that pops the brace counter, so
          # an mjml-no-curly-interpolation that came before mjml-raw-text ends here
          Tags.raw_text?(name, attrs) ->
            handle_raw_text(rest, name, line, column + 1, [], acc, end_childless_tag(acc, state))

          # Void tags have no closing tag to pop the brace counter
          meta[:closing] == :void ->
            handle_text(rest, line, column + 1, [], acc, end_childless_tag(acc, state))

          true ->
            handle_text(rest, line, column + 1, [], acc, push_braces(state))
        end

      acc ->
        handle_text(rest, line, column + 1, [], acc, push_braces(state))
    end
  end

  defp handle_maybe_tag_open_end("{" <> rest, line, column, acc, %{interpolation: true} = state) do
    handle_root_attribute(rest, line, column + 1, acc, state)
  end

  defp handle_maybe_tag_open_end(<<>>, line, column, _acc, state) do
    message = ~S"""
    expected closing `>` or `/>`

    Make sure the tag is properly closed. This may happen if there
    is an EEx interpolation inside a tag, which is not supported.
    For instance, instead of

        <div id="<%= @id %>">Content</div>

    do

        <div id={@id}>Content</div>

    If @id is nil or false, then no attribute is sent at all.

    Inside {...} you can place any Elixir expression. If you want
    to interpolate in the middle of an attribute value, instead of

        <a class="foo bar <%= @class %>">Text</a>

    you can pass an Elixir string with interpolation:

        <a class={"foo bar #{@class}"}>Text</a>
    """

    raise_syntax_error!(message, %{line: line, column: column}, state)
  end

  defp handle_maybe_tag_open_end(text, line, column, acc, state) do
    handle_attribute(text, line, column, acc, state)
  end

  ## handle_attribute

  defp handle_attribute(text, line, column, acc, state) do
    case handle_attr_name(text, column, []) do
      {:ok, name, new_column, rest} ->
        attr_meta = %{line: line, column: column}
        {text, line, column, value} = handle_maybe_attr_value(rest, line, new_column, state)
        acc = put_attr(acc, name, attr_meta, value)
        maybe_warn_missing_attr_space(value, text, line, column, state)

        state =
          if name == Tags.no_curly_interpolation_attribute() and state.braces == :enabled and
               not raw_text?(acc) do
            %{state | braces: 0}
          else
            state
          end

        handle_maybe_tag_open_end(text, line, column, acc, state)

      {:error, message, column} ->
        meta = %{line: line, column: column}
        raise_syntax_error!(message, meta, state)
    end
  end

  defp maybe_warn_missing_attr_space(nil, _text, _line, _column, _state), do: :ok
  defp maybe_warn_missing_attr_space(_value, _text, _line, _column, %{interpolation: false}), do: :ok

  defp maybe_warn_missing_attr_space(_value, <<c, _::binary>>, line, column, state)
       when c not in @space_chars and c not in ~c">/\r\n" do
    IO.warn(
      "missing space before attribute",
      line: line,
      column: column,
      file: state.file
    )
  end

  defp maybe_warn_missing_attr_space(_value, _text, _line, _column, _state), do: :ok

  defp raw_text?([{:tag, name, attrs, _} | _]), do: Tags.raw_text?(name, attrs)
  defp raw_text?(_), do: false

  ## handle_root_attribute

  defp handle_root_attribute(text, line, column, acc, state) do
    case handle_interpolation(text, line, column, [], 0, state) do
      {:ok, value, new_line, new_column, rest} ->
        meta = %{line: line, column: column}
        acc = put_attr(acc, :root, meta, {:expr, value, meta})
        handle_maybe_tag_open_end(rest, new_line, new_column, acc, state)

      {:error, message} ->
        # We do column - 1 to point to the opening {
        meta = %{line: line, column: column - 1}
        raise_syntax_error!(message, meta, state)
    end
  end

  ## handle_attr_name

  defp handle_attr_name(<<"}"::utf8, _rest::binary>>, column, _buffer) do
    {:error, "expected attribute, but found end of interpolation: }", column}
  end

  defp handle_attr_name(<<c::utf8, _rest::binary>>, column, _buffer)
       when c in @quote_chars do
    {:error, "invalid character in attribute name: #{<<c>>}", column}
  end

  defp handle_attr_name(<<c::utf8, _rest::binary>>, column, [])
       when c in @stop_chars do
    {:error, "expected attribute name", column}
  end

  defp handle_attr_name(<<c::utf8, _rest::binary>> = text, column, buffer)
       when c in @stop_chars do
    {:ok, buffer_to_string(buffer), column, text}
  end

  defp handle_attr_name(<<c::utf8, rest::binary>>, column, buffer) do
    handle_attr_name(rest, column + 1, [char_or_bin(c) | buffer])
  end

  defp handle_attr_name(<<>>, column, _buffer) do
    {:error, "unexpected end of string inside tag", column}
  end

  ## handle_maybe_attr_value

  defp handle_maybe_attr_value("\r\n" <> rest, line, _column, state) do
    handle_maybe_attr_value(rest, line + 1, state.column_offset, state)
  end

  defp handle_maybe_attr_value("\n" <> rest, line, _column, state) do
    handle_maybe_attr_value(rest, line + 1, state.column_offset, state)
  end

  defp handle_maybe_attr_value(<<c::utf8, rest::binary>>, line, column, state)
       when c in @space_chars do
    handle_maybe_attr_value(rest, line, column + 1, state)
  end

  defp handle_maybe_attr_value("=" <> rest, line, column, state) do
    handle_attr_value_begin(rest, line, column + 1, state)
  end

  defp handle_maybe_attr_value(text, line, column, _state) do
    {text, line, column, nil}
  end

  ## handle_attr_value_begin

  defp handle_attr_value_begin("\r\n" <> rest, line, _column, state) do
    handle_attr_value_begin(rest, line + 1, state.column_offset, state)
  end

  defp handle_attr_value_begin("\n" <> rest, line, _column, state) do
    handle_attr_value_begin(rest, line + 1, state.column_offset, state)
  end

  defp handle_attr_value_begin(<<c::utf8, rest::binary>>, line, column, state)
       when c in @space_chars do
    handle_attr_value_begin(rest, line, column + 1, state)
  end

  defp handle_attr_value_begin("\"" <> rest, line, column, state) do
    handle_attr_value_quote(rest, ?", line, column + 1, [], state)
  end

  defp handle_attr_value_begin("'" <> rest, line, column, state) do
    handle_attr_value_quote(rest, ?', line, column + 1, [], state)
  end

  defp handle_attr_value_begin("{" <> rest, line, column, %{interpolation: true} = state) do
    handle_attr_value_as_expr(rest, line, column + 1, state)
  end

  defp handle_attr_value_begin(_text, line, column, %{interpolation: false} = state) do
    message = "invalid attribute value after `=`. Expected a value between quotes (such as \"value\" or \'value\')"
    raise_syntax_error!(message, %{line: line, column: column}, state)
  end

  defp handle_attr_value_begin(_text, line, column, state) do
    message =
      "invalid attribute value after `=`. Expected either a value between quotes " <>
        "(such as \"value\" or \'value\') or an Elixir expression between curly braces (such as `{expr}`)"

    meta = %{line: line, column: column}
    raise_syntax_error!(message, meta, state)
  end

  ## handle_attr_value_quote

  defp handle_attr_value_quote("\r\n" <> rest, delim, line, _column, buffer, state) do
    column = state.column_offset
    handle_attr_value_quote(rest, delim, line + 1, column, ["\r\n" | buffer], state)
  end

  defp handle_attr_value_quote("\n" <> rest, delim, line, _column, buffer, state) do
    column = state.column_offset
    handle_attr_value_quote(rest, delim, line + 1, column, ["\n" | buffer], state)
  end

  defp handle_attr_value_quote(<<delim, rest::binary>>, delim, line, column, buffer, _state) do
    value = buffer_to_string(buffer)
    {rest, line, column + 1, {:string, value, %{delimiter: delim}}}
  end

  defp handle_attr_value_quote(<<c::utf8, rest::binary>>, delim, line, column, buffer, state) do
    handle_attr_value_quote(rest, delim, line, column + 1, [char_or_bin(c) | buffer], state)
  end

  defp handle_attr_value_quote(<<>>, delim, line, column, _buffer, state) do
    message = """
    expected closing `#{<<delim>>}` for attribute value

    Make sure the attribute is properly closed. This may also happen if
    there is EEx inside an attribute value or a tag, which is not supported.
    Instead of

        <mj-button href="<%= @url %>">

    write

        <mj-button href={@url}>

    and instead of <div <%= @attributes %>>, write <div {@attributes}>,
    where @attributes is a keyword list or a map.
    """

    meta = %{line: line, column: column}
    raise_syntax_error!(message, meta, state)
  end

  ## handle_attr_value_as_expr

  defp handle_attr_value_as_expr(text, line, column, state) do
    case handle_interpolation(text, line, column, [], 0, state) do
      {:ok, value, new_line, new_column, rest} ->
        {rest, new_line, new_column, {:expr, value, %{line: line, column: column}}}

      {:error, message} ->
        # We do column - 1 to point to the opening {
        meta = %{line: line, column: column - 1}
        raise_syntax_error!(message, meta, state)
    end
  end

  ## handle_interpolation

  defp handle_interpolation("\r\n" <> rest, line, _column, buffer, braces, state) do
    handle_interpolation(rest, line + 1, state.column_offset, ["\r\n" | buffer], braces, state)
  end

  defp handle_interpolation("\n" <> rest, line, _column, buffer, braces, state) do
    handle_interpolation(rest, line + 1, state.column_offset, ["\n" | buffer], braces, state)
  end

  defp handle_interpolation("}" <> rest, line, column, buffer, 0, _state) do
    value = buffer_to_string(buffer)
    {:ok, value, line, column + 1, rest}
  end

  defp handle_interpolation(~S(\}) <> rest, line, column, buffer, braces, state) do
    handle_interpolation(rest, line, column + 2, [~S(\}) | buffer], braces, state)
  end

  defp handle_interpolation(~S(\{) <> rest, line, column, buffer, braces, state) do
    handle_interpolation(rest, line, column + 2, [~S(\{) | buffer], braces, state)
  end

  defp handle_interpolation("}" <> rest, line, column, buffer, braces, state) do
    handle_interpolation(rest, line, column + 1, ["}" | buffer], braces - 1, state)
  end

  defp handle_interpolation("{" <> rest, line, column, buffer, braces, state) do
    handle_interpolation(rest, line, column + 1, ["{" | buffer], braces + 1, state)
  end

  defp handle_interpolation(<<c::utf8, rest::binary>>, line, column, buffer, braces, state) do
    handle_interpolation(rest, line, column + 1, [char_or_bin(c) | buffer], braces, state)
  end

  defp handle_interpolation(<<>>, _line, _column, _buffer, _braces, _state) do
    {:error,
     """
     expected closing `}` for expression

     In case you don't want `{` to begin a new interpolation, \
     you may write it using `&#123;` or using `<%= "{" %>`\
     """}
  end

  ## helpers

  # Plain MJML has no components or slots: every tag is an element
  defp classify_type(name, %{interpolation: false}), do: {:tag, name}
  defp classify_type(name, _state), do: Tags.classify_type(name)

  @compile {:inline, ok: 2, char_or_bin: 1}
  defp ok(acc, cont), do: {acc, cont}

  defp char_or_bin(c) when c <= 127, do: c
  defp char_or_bin(c), do: <<c::utf8>>

  defp buffer_to_string(buffer) do
    IO.iodata_to_binary(Enum.reverse(buffer))
  end

  defp text_to_acc(buffer, acc, line, column, context, start)

  defp text_to_acc([], acc, _line, _column, _context, _start),
    do: acc

  defp text_to_acc(buffer, acc, line, column, context, {start_line, start_column}) do
    meta = %{line: start_line, column: start_column, line_end: line, column_end: column}

    meta =
      if context == [] do
        meta
      else
        Map.put(meta, :context, trim_context(context))
      end

    [{:text, buffer_to_string(buffer), meta} | acc]
  end

  defp trim_context([:comment_end, :comment_start | [_ | _] = rest]), do: trim_context(rest)
  defp trim_context(rest), do: Enum.reverse(rest)

  # A void or self-closing tag with the no-curly-interpolation attribute ends the region it started
  defp end_childless_tag([{_type, _name, attrs, _meta} | _], %{braces: 0} = state) do
    if List.keymember?(attrs, Tags.no_curly_interpolation_attribute(), 0),
      do: %{state | braces: :enabled},
      else: state
  end

  defp end_childless_tag(_acc, state), do: state

  defp push_braces(%{braces: :enabled} = state), do: state
  defp push_braces(%{braces: :disabled} = state), do: state
  defp push_braces(%{braces: braces} = state), do: %{state | braces: braces + 1}

  defp pop_braces(%{braces: :enabled} = state), do: state
  defp pop_braces(%{braces: :disabled} = state), do: state
  defp pop_braces(%{braces: 1} = state), do: %{state | braces: :enabled}
  defp pop_braces(%{braces: braces} = state), do: %{state | braces: braces - 1}

  defp put_attr([{type, name, attrs, meta} | acc], attr, attr_meta, value) do
    attrs = [{attr, value, attr_meta} | attrs]
    [{type, name, attrs, meta} | acc]
  end

  defp normalize_tag([{type, name, attrs, meta} | acc], line, column, self_close?, _state) do
    attrs = Enum.reverse(attrs)
    meta = %{meta | inner_location: {line, column}}

    meta =
      cond do
        type == :tag and Tags.void?(name) -> Map.put(meta, :closing, :void)
        self_close? -> Map.put(meta, :closing, :self)
        true -> meta
      end

    [{type, name, attrs, meta} | acc]
  end

  defp strip_text_token_fully(tokens) do
    with [{:text, text, _} | rest] <- tokens,
         "" <- String.trim_leading(text) do
      strip_text_token_fully(rest)
    else
      _ -> tokens
    end
  end

  defp raise_syntax_error!(message, meta, state) do
    raise ParseError,
      file: state.file,
      line: meta.line,
      column: meta.column,
      description: message <> ParseError.code_snippet(state.source, meta, state.indentation)
  end
end
