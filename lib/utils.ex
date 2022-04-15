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
  def encode_expression(marker, expression) do
    encoded_code = Base.encode16("<%#{marker} #{Macro.to_string(expression)} %>")

    "__MJML_EEX_START__:#{encoded_code}:__MJML_EEX_END__"
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
end
