defmodule MjmlEEx do
  @moduledoc """
  Documentation for `MjmlEEx`.
  """

  alias MjmlEEx.Utils

  defmacro __using__(opts) do
    mjml_template =
      case Keyword.fetch(opts, :mjml_template) do
        {:ok, mjml_template} ->
          %Macro.Env{file: calling_module_file} = __CALLER__

          calling_module_file
          |> Path.dirname()
          |> Path.join(mjml_template)

        :error ->
          raise "The :mjml_template option is required."
      end

    unless File.exists?(mjml_template) do
      raise "The provided :mjml_template does not exist at #{inspect(mjml_template)}"
    end

    phoenix_html_ast = compile(mjml_template)

    created_code =
      quote do
        @template_path unquote(mjml_template)
        @external_resource unquote(mjml_template)

        @doc "Safely render the MJML template using Phoenix.HTML"
        def render(assigns) do
          assigns
          |> apply_assigns_to_template()
          |> Phoenix.HTML.safe_to_string()
        end

        defp apply_assigns_to_template(var!(assigns)) do
          _ = var!(assigns)
          unquote(phoenix_html_ast)
        end
      end

    created_code
    |> Macro.to_string()

    created_code
  end

  defp compile(path) do
    {mjml_document, _} =
      path
      |> EEx.compile_file(engine: MjmlEEx.Engines.Mjml, line: 1, trim: true)
      |> Code.eval_quoted()

    mjml_document
    |> Mjml.to_html()
    |> case do
      {:ok, email_html} ->
        email_html

      error ->
        raise "Failed to compile MJML template: #{inspect(error)}"
    end
    |> Utils.decode_eex_expressions()
    |> EEx.compile_string(engine: Phoenix.HTML.Engine, line: 1)
  end
end
