defmodule MjmlEEx.Tokenizer do
  # Taken from until Elixir 1.14.0 comes out: https://github.com/elixir-lang/elixir/blob/main/lib/eex/lib/eex/compiler.ex
  @moduledoc false

  @h_spaces [?\s, ?\t]

  @doc false
  def tokenize(contents, opts) when is_binary(contents) do
    tokenize(String.to_charlist(contents), opts)
  end

  def tokenize(contents, opts) when is_list(contents) do
    file = opts[:file] || "nofile"
    line = opts[:line] || 1
    trim = opts[:trim] || false
    indentation = opts[:indentation] || 0
    column = indentation + (opts[:column] || 1)

    state = %{trim: trim, indentation: indentation, file: file}

    {contents, line, column} = (trim && trim_init(contents, line, column, state)) || {contents, line, column}

    tokenize(contents, line, column, state, [{line, column}], [])
  end

  defp tokenize('<%%' ++ t, line, column, state, buffer, acc) do
    tokenize(t, line, column + 3, state, [?%, ?< | buffer], acc)
  end

  defp tokenize('<%!--' ++ t, line, column, state, buffer, acc) do
    case comment(t, line, column + 5, state, []) do
      {:error, line, column, message} ->
        {:error, message, %{line: line, column: column}}

      {:ok, new_line, new_column, rest, comments} ->
        token = {:comment, Enum.reverse(comments), %{line: line, column: column}}
        trim_and_tokenize(rest, new_line, new_column, state, buffer, acc, &[token | &1])
    end
  end

  defp tokenize('<%#' ++ t, line, column, state, buffer, acc) do
    case expr(t, line, column + 3, state, []) do
      {:error, line, column, message} ->
        {:error, message, %{line: line, column: column}}

      {:ok, _, new_line, new_column, rest} ->
        trim_and_tokenize(rest, new_line, new_column, state, buffer, acc, & &1)
    end
  end

  defp tokenize('<%' ++ t, line, column, state, buffer, acc) do
    {marker, t} = retrieve_marker(t)

    case expr(t, line, column + 2 + length(marker), state, []) do
      {:error, line, column, message} ->
        {:error, message, %{line: line, column: column}}

      {:ok, expr, new_line, new_column, rest} ->
        {key, expr} =
          case :elixir_tokenizer.tokenize(expr, 1, file: "eex", check_terminators: false) do
            {:ok, _line, _column, warnings, tokens} ->
              Enum.each(Enum.reverse(warnings), fn {location, file, msg} ->
                :elixir_errors.erl_warn(location, file, msg)
              end)

              token_key(tokens, expr)

            {:error, _, _, _, _} ->
              {:expr, expr}
          end

        marker =
          if key in [:middle_expr, :end_expr] and marker != '' do
            message = """
            unexpected beginning of EEx tag \"<%#{marker}\" on \"<%#{marker}#{expr}%>\", please remove \"#{marker}\"
            """

            :elixir_errors.erl_warn({line, column}, state.file, message)
            ''
          else
            marker
          end

        token = {key, marker, expr, %{line: line, column: column}}
        trim_and_tokenize(rest, new_line, new_column, state, buffer, acc, &[token | &1])
    end
  end

  defp tokenize('\n' ++ t, line, _column, state, buffer, acc) do
    tokenize(t, line + 1, state.indentation + 1, state, [?\n | buffer], acc)
  end

  defp tokenize([h | t], line, column, state, buffer, acc) do
    tokenize(t, line, column + 1, state, [h | buffer], acc)
  end

  defp tokenize([], line, column, _state, buffer, acc) do
    eof = {:eof, %{line: line, column: column}}
    {:ok, Enum.reverse([eof | tokenize_text(buffer, acc)])}
  end

  defp trim_and_tokenize(rest, line, column, state, buffer, acc, fun) do
    {rest, line, column, buffer} = trim_if_needed(rest, line, column, state, buffer)

    acc = tokenize_text(buffer, acc)
    tokenize(rest, line, column, state, [{line, column}], fun.(acc))
  end

  # Retrieve marker for <%

  defp retrieve_marker([marker | t]) when marker in [?=, ?/, ?|] do
    {[marker], t}
  end

  defp retrieve_marker(t) do
    {'', t}
  end

  # Tokenize a multi-line comment until we find --%>

  defp comment([?-, ?-, ?%, ?> | t], line, column, _state, buffer) do
    {:ok, line, column + 4, t, buffer}
  end

  defp comment('\n' ++ t, line, _column, state, buffer) do
    comment(t, line + 1, state.indentation + 1, state, '\n' ++ buffer)
  end

  defp comment([head | t], line, column, state, buffer) do
    comment(t, line, column + 1, state, [head | buffer])
  end

  defp comment([], line, column, _state, _buffer) do
    {:error, line, column, "missing token '--%>'"}
  end

  # Tokenize an expression until we find %>

  defp expr([?%, ?> | t], line, column, _state, buffer) do
    {:ok, Enum.reverse(buffer), line, column + 2, t}
  end

  defp expr('\n' ++ t, line, _column, state, buffer) do
    expr(t, line + 1, state.indentation + 1, state, [?\n | buffer])
  end

  defp expr([h | t], line, column, state, buffer) do
    expr(t, line, column + 1, state, [h | buffer])
  end

  defp expr([], line, column, _state, _buffer) do
    {:error, line, column, "missing token '%>'"}
  end

  # Receives tokens and check if it is a start, middle or an end token.
  defp token_key(tokens, expr) do
    case {tokens, tokens |> Enum.reverse() |> drop_eol()} do
      {[{:end, _} | _], [{:do, _} | _]} ->
        {:middle_expr, expr}

      {_, [{:do, _} | _]} ->
        {:start_expr, maybe_append_space(expr)}

      {_, [{:block_identifier, _, _} | _]} ->
        {:middle_expr, maybe_append_space(expr)}

      {[{:end, _} | _], [{:stab_op, _, _} | _]} ->
        {:middle_expr, expr}

      {_, [{:stab_op, _, _} | reverse_tokens]} ->
        fn_index = Enum.find_index(reverse_tokens, &match?({:fn, _}, &1)) || :infinity
        end_index = Enum.find_index(reverse_tokens, &match?({:end, _}, &1)) || :infinity

        if end_index > fn_index do
          {:start_expr, expr}
        else
          {:middle_expr, expr}
        end

      {tokens, _} ->
        case Enum.drop_while(tokens, &closing_bracket?/1) do
          [{:end, _} | _] -> {:end_expr, expr}
          _ -> {:expr, expr}
        end
    end
  end

  defp drop_eol([{:eol, _} | rest]), do: drop_eol(rest)
  defp drop_eol(rest), do: rest

  defp maybe_append_space([?\s]), do: [?\s]
  defp maybe_append_space([h]), do: [h, ?\s]
  defp maybe_append_space([h | t]), do: [h | maybe_append_space(t)]

  defp closing_bracket?({closing, _}) when closing in ~w"( [ {"a, do: true
  defp closing_bracket?(_), do: false

  # Tokenize the buffered text by appending
  # it to the given accumulator.

  defp tokenize_text([{_line, _column}], acc) do
    acc
  end

  defp tokenize_text(buffer, acc) do
    [{line, column} | buffer] = Enum.reverse(buffer)
    [{:text, buffer, %{line: line, column: column}} | acc]
  end

  ## Trim

  defp trim_if_needed(rest, line, column, state, buffer) do
    if state.trim do
      buffer = trim_left(buffer, 0)
      {rest, line, column} = trim_right(rest, line, column, 0, state)
      {rest, line, column, buffer}
    else
      {rest, line, column, buffer}
    end
  end

  defp trim_init([h | t], line, column, state) when h in @h_spaces,
    do: trim_init(t, line, column + 1, state)

  defp trim_init([?\r, ?\n | t], line, _column, state),
    do: trim_init(t, line + 1, state.indentation + 1, state)

  defp trim_init([?\n | t], line, _column, state),
    do: trim_init(t, line + 1, state.indentation + 1, state)

  defp trim_init([?<, ?% | _] = rest, line, column, _state),
    do: {rest, line, column}

  defp trim_init(_, _, _, _), do: false

  defp trim_left(buffer, count) do
    case trim_whitespace(buffer, 0) do
      {[?\n, ?\r | rest], _} -> trim_left(rest, count + 1)
      {[?\n | rest], _} -> trim_left(rest, count + 1)
      _ when count > 0 -> [?\n | buffer]
      _ -> buffer
    end
  end

  defp trim_right(rest, line, column, last_column, state) do
    case trim_whitespace(rest, column) do
      {[?\r, ?\n | rest], column} ->
        trim_right(rest, line + 1, state.indentation + 1, column + 1, state)

      {[?\n | rest], column} ->
        trim_right(rest, line + 1, state.indentation + 1, column, state)

      {[], column} ->
        {[], line, column}

      _ when last_column > 0 ->
        {[?\n | rest], line - 1, last_column}

      _ ->
        {rest, line, column}
    end
  end

  defp trim_whitespace([h | t], column) when h in @h_spaces, do: trim_whitespace(t, column + 1)
  defp trim_whitespace(list, column), do: {list, column}
end
