defmodule MjmlEEx.CompileError do
  @moduledoc """
  Raised when the compiler can't compile MJML to HTML, by an email module's `to_html/1` or
  by `MjmlEEx.to_html/2`.

  Templates are checked against the MJML spec when they compile, so this is rare for email
  modules. It's more likely for MJML strings passed to `MjmlEEx.to_html/2`, such as MJML from
  a CMS:

  ```elixir
  try do
    {:ok, MjmlEEx.to_html(mjml)}
  rescue
    error in MjmlEEx.CompileError -> {:error, error.reason}
  end
  ```

  - `:reason` - the error the compiler returned, such as mjml_nif's message.
  - `:module` - the email module, or `nil` for `MjmlEEx.to_html/2`.
  """

  defexception [:reason, :module]

  @type t :: %__MODULE__{reason: term(), module: module() | nil}

  @impl true
  def message(%__MODULE__{reason: reason, module: nil}), do: "couldn't compile the MJML to HTML: #{format(reason)}"

  def message(%__MODULE__{reason: reason, module: module}),
    do: "couldn't compile the MJML of #{inspect(module)} to HTML: #{format(reason)}"

  defp format(reason) when is_binary(reason), do: reason
  defp format(reason), do: inspect(reason)
end
