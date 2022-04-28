defmodule MjmlEEx do
  @moduledoc """
  Documentation for `MjmlEEx` template module. This moule contains the macro
  that is used to create an MJML EEx template.

  You can use this module like so:

  ```elixir
  defmodule BasicTemplate do
    use MjmlEEx, mjml_template: "basic_template.mjml.eex"
  end
  ```

  Along with the `basic_template.mjml.eex MJML` template located in the same
  directory as the module containing the following:

  ```html
  <mjml>
    <mj-body>
      <mj-section>
        <mj-column>
          <mj-divider border-color="#F45E43"></mj-divider>
          <mj-text font-size="20px" color="#F45E43">Hello <%= @first_name %> <%= @last_name %>!</mj-text>
        </mj-column>
      </mj-section>
    </mj-body>
  </mjml>
  ```

  Once that is in place, you can render the final HTML document by running:

  ```elixir
  BasicTemplate.render(first_name: "Alex", last_name: "Koutmos")
  ```
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
      raise "The provided :mjml_template does not exist at #{inspect(mjml_template)}."
    end

    # Get the options passed to the macro or set the defaults
    layout_module = opts |> Keyword.get(:layout, :none) |> Macro.expand(__CALLER__)
    compilation_mode = Keyword.get(opts, :mode, :runtime)

    unless layout_module == :none do
      Code.ensure_compiled!(layout_module)
    end

    raw_mjml_template =
      case layout_module do
        :none ->
          get_raw_template(mjml_template, __CALLER__)

        module when is_atom(module) ->
          get_raw_template_with_layout(mjml_template, layout_module, __CALLER__)

        invalid_layout ->
          raise "#{inspect(invalid_layout)} is an invalid layout option"
      end

    generate_functions(compilation_mode, raw_mjml_template, mjml_template, layout_module)
  end

  defp generate_functions(:runtime, raw_mjml_template, mjml_template_file, layout_module) do
    phoenix_html_ast = EEx.compile_string(raw_mjml_template, engine: Phoenix.HTML.Engine, line: 1)

    quote do
      @external_resource unquote(mjml_template_file)

      if unquote(layout_module) != :none do
        @external_resource unquote(layout_module).__layout_file__()
      end

      @doc "Returns the raw MJML template. Useful for debugging rendering issues."
      def debug_mjml_template do
        unquote(raw_mjml_template)
      end

      @doc "Safely render the MJML template using Phoenix.HTML"
      def render(assigns) do
        assigns
        |> apply_assigns_to_template()
        |> Phoenix.HTML.safe_to_string()
        |> Mjml.to_html()
        |> case do
          {:ok, email_html} ->
            email_html

          {:error, error} ->
            raise "Failed to compile MJML template: #{inspect(error)}"
        end
      end

      defp apply_assigns_to_template(var!(assigns)) do
        _ = var!(assigns)
        unquote(phoenix_html_ast)
      end
    end
  end

  defp generate_functions(:compile, raw_mjml_template, mjml_template_file, layout_module) do
    phoenix_html_ast =
      raw_mjml_template
      |> Utils.escape_eex_expressions()
      |> Mjml.to_html()
      |> case do
        {:ok, email_html} ->
          email_html

        {:error, error} ->
          raise "Failed to compile MJML template: #{inspect(error)}"
      end
      |> Utils.decode_eex_expressions()
      |> EEx.compile_string(engine: Phoenix.HTML.Engine, line: 1)

    quote do
      @external_resource unquote(mjml_template_file)

      if unquote(layout_module) != :none do
        @external_resource unquote(layout_module).__layout_file__()
      end

      @doc "Returns the escaped MJML template. Useful for debugging rendering issues."
      def debug_mjml_template do
        unquote(raw_mjml_template)
      end

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
  end

  defp generate_functions(invalid_mode, _, _, _) do
    raise "#{inspect(invalid_mode)} is an invalid :mode. Possible values are :runtime or :compile"
  end

  defp get_raw_template(template_path, caller) do
    {mjml_document, _} =
      template_path
      |> File.read!()
      |> Utils.escape_eex_expressions()
      |> EEx.compile_string(engine: MjmlEEx.Engines.Mjml, line: 1, trim: true, caller: caller)
      |> Code.eval_quoted()

    Utils.decode_eex_expressions(mjml_document)
  end

  defp get_raw_template_with_layout(template_path, layout_module, caller) do
    template_file_contents = File.read!(template_path)
    pre_inner_content = layout_module.pre_inner_content()
    post_inner_content = layout_module.post_inner_content()

    {mjml_document, _} =
      [pre_inner_content, template_file_contents, post_inner_content]
      |> Enum.join()
      |> Utils.escape_eex_expressions()
      |> EEx.compile_string(engine: MjmlEEx.Engines.Mjml, line: 1, trim: true, caller: caller)
      |> Code.eval_quoted()

    Utils.decode_eex_expressions(mjml_document)
  end
end
