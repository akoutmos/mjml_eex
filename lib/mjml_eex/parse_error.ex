# Adapted from Phoenix.LiveView.TagEngine.Tokenizer.ParseError in Phoenix LiveView v1.2.12
# (lib/phoenix_live_view/tag_engine/tokenizer.ex, https://github.com/phoenixframework/phoenix_live_view,
# commit 83ab190). Phoenix LiveView is MIT licensed: Copyright (c) 2018 Chris McCord.
defmodule MjmlEEx.ParseError do
  @moduledoc """
  Raised when an MJML template can't be parsed, for example because a tag is never
  closed. `line` and `column` point to the problem, and `description` includes a
  snippet of the source.
  """

  defexception [:file, :line, :column, :description]

  @type t :: %__MODULE__{
          file: String.t(),
          line: pos_integer(),
          column: pos_integer(),
          description: String.t()
        }

  @impl true
  def message(exception) do
    location =
      exception.file
      |> Path.relative_to_cwd()
      |> Exception.format_file_line_column(exception.line, exception.column)

    "#{location} #{exception.description}"
  end

  @doc false
  # Templates in ~MJML sigils start partway through a file, while error lines count from the
  # start of the file. Code snippets are taken from this, with the template on its own lines.
  def snippet_source(source, first_line), do: String.duplicate("\n", max(first_line - 1, 0)) <> source

  @doc false
  def code_snippet(source, meta, indentation \\ 0) do
    lines = String.split(source, ["\r\n", "\n"])
    line_end = meta.line

    # Leading blank lines (including the lines before a sigil's template) are left out
    line_start =
      Enum.find(max(line_end - 3, 1)..line_end//1, line_end, fn line ->
        String.trim(Enum.at(lines, line - 1, "")) != ""
      end)

    digits = line_end |> Integer.to_string() |> byte_size()
    number_padding = String.duplicate(" ", digits)
    indentation = String.duplicate(" ", indentation)

    lines
    |> Enum.slice((line_start - 1)..(line_end - 1)//1)
    |> Enum.map_reduce(line_start, fn
      expr, line_number when line_number == line_end ->
        arrow = String.duplicate(" ", max(meta.column - 1, 0)) <> "^"
        acc = "#{line_number} | #{indentation}#{expr}\n #{number_padding}| #{arrow}"
        {acc, line_number + 1}

      expr, line_number ->
        line_number_padding = String.pad_leading("#{line_number}", digits)
        {"#{line_number_padding} | #{indentation}#{expr}", line_number + 1}
    end)
    |> case do
      {[], _} ->
        ""

      {snippet, _} ->
        Enum.join(["\n #{number_padding}|" | snippet], "\n")
    end
  end
end
