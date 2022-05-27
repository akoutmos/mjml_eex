defmodule MjmlEEx.Compilers.Rust do
  @moduledoc """
  This module implements the `MjmlEEx.Compiler` behaviour
  and allows you to compile your MJML templates using the Rust
  NIF (https://hexdocs.pm/mjml/readme.html).

  This is the default compiler.
  """

  @behaviour MjmlEEx.Compiler

  @impl true
  def compile(mjml_template) do
    Mjml.to_html(mjml_template)
  end
end
