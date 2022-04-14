defmodule MjmlEEx.Utils do
  @moduledoc """
  General MJML EEx utils reside here for encoding and decoding
  Elixir expressions in MJML EEx templates.
  """
  def encode_expression(marker, expression) do
    Base.encode16("<%#{marker} #{Macro.to_string(expression)} %>")
  end

  def decode_expression(encoded_string) do
    Base.decode16!(encoded_string)
  end

  def decode_eex_expressions(email_document) do
    ~r/__MJML_EEX_START__:([^:]+):__MJML_EEX_END__/
    |> Regex.replace(email_document, fn _, base16_code ->
      "#{decode_expression(base16_code)}"
    end)
  end
end
