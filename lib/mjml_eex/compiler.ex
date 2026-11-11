defmodule MjmlEEx.Compiler do
  @moduledoc """
  This module defines the behaviour that all compiler implementations
  need to adhere to.

  A compiler implements `c:compile/2`, which receives the MJML template along
  with the merged compiler options (see `MjmlEEx.compiler_opts/1`). Compilers
  that only implement `c:compile/1` continue to work, but they will not receive
  any compiler options.
  """

  @type compile_result :: {:ok, String.t()} | {:error, String.t()}

  @doc "Compile the MJML template into HTML without any compiler options."
  @callback compile(mjml_template :: String.t()) :: compile_result()

  @doc "Compile the MJML template into HTML using the provided compiler options."
  @callback compile(mjml_template :: String.t(), opts :: keyword()) :: compile_result()

  @optional_callbacks compile: 1, compile: 2

  @doc """
  Compile the MJML template with the given compiler module. If the compiler
  implements `c:compile/2`, the options are passed along. Otherwise `c:compile/1`
  is called and the options are ignored.
  """
  @spec compile(compiler :: module(), mjml_template :: String.t(), opts :: keyword()) :: compile_result()
  def compile(compiler, mjml_template, opts) do
    Code.ensure_loaded(compiler)

    if function_exported?(compiler, :compile, 2) do
      compiler.compile(mjml_template, opts)
    else
      compiler.compile(mjml_template)
    end
  end
end
