defmodule MjmlEEx.Utils do
  @moduledoc """
  General MJML EEx utils reside here for encoding and decoding
  Elixir expressions in MJML EEx templates.
  """

  @doc """
  This function encodes the internals of an MJML EEx document
  so that when it is compiled, the EEx expressions don't break
  the MJML compiler.
  """
  def encode_expression(marker, expression) when is_binary(expression) do
    encoded_code = Base.encode16("<%#{marker} #{String.trim(expression)} %>")

    "__MJML_EEX_START__:#{encoded_code}:__MJML_EEX_END__"
  end

  def encode_expression(marker, expression) when is_list(expression) do
    encode_expression(marker, List.to_string(expression))
  end

  @doc """
  This function finds all of the instances of of encoded EEx expressions
  and decodes them so that when the EEx HTML template is finally
  rendered, the expressions are executed as expected.
  """
  def decode_eex_expressions(email_document) do
    ~r/__MJML_EEX_START__:([^:]+):__MJML_EEX_END__/
    |> Regex.replace(email_document, fn _, base16_code ->
      "#{decode_expression(base16_code)}"
    end)
  end

  defp decode_expression(encoded_string) do
    Base.decode16!(encoded_string)
  end

  @doc """
  This function goes through and espaces all non-special EEx expressions
  so that they do not throw off the the MJML compiler.
  """
  def escape_eex_expressions(template) do
    template
    |> MjmlEEx.Tokenizer.tokenize([])
    |> case do
      {:ok, tokens} ->
        reduce_tokens(tokens)

      error ->
        raise "Failed to tokenize EEx template: #{inspect(error)}"
    end
  end

  defp reduce_tokens(tokens) do
    tokens
    |> Enum.reduce("", fn
      {:text, content, _location}, acc ->
        additional_content = List.to_string(content)
        acc <> additional_content

      {token, marker, expression, _location}, acc when token in [:expr, :start_expr, :middle_expr, :end_expr] ->
        captured_expression =
          expression
          |> List.to_string()
          |> Code.string_to_quoted()

        case captured_expression do
          {:ok, {:render_component, _line, _args}} ->
            acc <> "<%#{normalize_marker(marker)} #{List.to_string(expression)} %>"

          _ ->
            acc <> encode_expression(normalize_marker(marker), expression)
        end

      {:eof, _location}, acc ->
        acc
    end)
  end

  defp normalize_marker([]), do: ""
  defp normalize_marker(marker), do: List.to_string(marker)
end
