defmodule MjmlEEx.Compiler do
  @moduledoc """
  This module defines the behaviour that all compiler implementations
  need to adhere to.
  """

  @callback compile(mjml_template :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
end
