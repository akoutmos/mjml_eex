defmodule MjmlEEx do
  @moduledoc """
  Documentation for `MjmlEEx`.
  """

  defmacro __using__(opts) do
    mjml_file =
      case Keyword.fetch(opts, :mjml_file) do
        {:ok, mjml_file} ->
          %Macro.Env{file: calling_module_file} = __CALLER__

          calling_module_file
          |> Path.dirname()
          |> Path.join(mjml_file)

        :error ->
          raise "The :mjml_file option is required."
      end

    unless File.exists?(mjml_file) do
      raise "The provided :mjml_file does not exist at #{inspect(mjml_file)}"
    end

    quote do
      require EEx

      @template_path unquote(mjml_file)
      @external_resource @template_path

      rendered_mjml = MjmlEEx.generate_eex_template(@template_path, unquote(opts))
      EEx.function_from_string(:def, :render, rendered_mjml, [:assigns])
    end
  end

  @doc """
  This function will read the MJML EEx file, tokenize all of the EEx clauses,
  convert the tokenized clauses into base64 encoded strings, compile the MJML
  template using the Rust MJML NIF compiler, and then finally convert all of the
  base64 encoded strings back into valid Elixir code.

  The reason for the base64 encoding/decoding step is to ensure that EEx
  `<%= ... %>` and `<% ... %>` statements do not break the Rust MJML compiler.
  """
  def generate_eex_template(file_path, opts) do
    {:ok, tokens} =
      file_path
      |> File.read!()
      |> EEx.Tokenizer.tokenize(1, 1, %{indentation: 0, trim: true})

    {:ok, email_html} =
      tokens
      |> Enum.reduce("", fn
        {:text, _, _, content}, acc ->
          additional_content = :binary.list_to_bin(content)
          acc <> additional_content

        {:expr, _, _, marker, content}, acc ->
          code = :binary.list_to_bin(content)
          encoded_code = Base.encode64("<%#{normalize_marker(marker)} #{code} %>")
          acc <> "MJML_EEX_START:#{encoded_code}:MJML_EEX_END"

        {:start_expr, _, _, marker, content}, acc ->
          code = :binary.list_to_bin(content)
          encoded_code = Base.encode64("<%#{normalize_marker(marker)} #{code} %>")
          acc <> "MJML_EEX_START:#{encoded_code}:MJML_EEX_END"

        {:middle_expr, _, _, marker, content}, acc ->
          code = :binary.list_to_bin(content)
          encoded_code = Base.encode64("<%#{normalize_marker(marker)} #{code} %>")
          acc <> "MJML_EEX_START:#{encoded_code}:MJML_EEX_END"

        {:end_expr, _, _, marker, content}, acc ->
          code = :binary.list_to_bin(content)
          encoded_code = Base.encode64("<%#{normalize_marker(marker)} #{code} %>")
          acc <> "MJML_EEX_START:#{encoded_code}:MJML_EEX_END"

        {:eof, _, _}, acc ->
          acc
      end)
      |> Mjml.to_html()

    email_html
    |> decode_eex_expressions()
    |> tap(fn output ->
      if Keyword.get(opts, :debug, false) do
        IO.puts("---------------- START COMPILED MJML TEMPLATE ----------------")
        IO.puts(output)
        IO.puts("---------------- END COMPILED MJML TEMPLATE ----------------")
      end
    end)
  end

  defp decode_eex_expressions(email_document) do
    ~r/MJML_EEX_START:([^:]+):MJML_EEX_END/
    |> Regex.replace(email_document, fn _, base64_code ->
      "#{Base.decode64!(base64_code)}"
    end)
  end

  defp normalize_marker([]), do: ""
  defp normalize_marker(marker), do: :binary.list_to_bin(marker)
end
