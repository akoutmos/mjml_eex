defmodule MjmlEEx.Layout do
  @moduledoc """
  This module allows you to define an MJML layout so that you
  can create reusable email skeletons. To use layouts with your
  MJML emails, create a layout template that contains an
  `<%= @inner_content %>` expression in it like so:

  ```html
  <mjml>
    <mj-head>
      <mj-title>Say hello to card</mj-title>
      <mj-font name="Roboto" href="https://fonts.googleapis.com/css?family=Montserrat:300,400,500"></mj-font>
      <mj-attributes>
        <mj-all font-family="Montserrat, Helvetica, Arial, sans-serif"></mj-all>
        <mj-text font-weight="400" font-size="16px" color="#000000" line-height="24px"></mj-text>
        <mj-section padding="<%= @padding %>"></mj-section>
      </mj-attributes>
    </mj-head>

    <%= @inner_content %>
  </mjml>
  ```

  You can also include additional assigns like `@padding` in this
  example. Just make sure that you provide that assign when you
  are rendering the final template. With that in place, you can
  define a layout module like so

  ```elixir
  defmodule BaseLayout do
    use MjmlEEx.Layout, mjml_layout: "base_layout.mjml.eex"
  end
  ```

  And then use it in conjunction with your templates like so:

  ```elixir
  defmodule MyTemplate do
    use MjmlEEx,
      mjml_template: "my_template.mjml.eex",
      layout: BaseLayout
  end
  ```

  Then in your template, all you need to provide are the portions that
  you need to complete the layout:

  ```html
  <mj-body>
    ...
  </mj-body>
  ```
  """

  defmacro __using__(opts) do
    mjml_layout =
      case Keyword.fetch(opts, :mjml_layout) do
        {:ok, mjml_layout} ->
          %Macro.Env{file: calling_module_file} = __CALLER__

          calling_module_file
          |> Path.dirname()
          |> Path.join(mjml_layout)

        :error ->
          raise "The :mjml_layout option is required."
      end

    # Ensure that the file exists
    unless File.exists?(mjml_layout) do
      raise "The provided :mjml_layout does not exist at #{inspect(mjml_layout)}."
    end

    # Extract the contents and ensure that it conforms to the
    # requirements for a layout
    layout_file_contents = File.read!(mjml_layout)

    # Extract the pre and post content sections
    [pre_inner_content, post_inner_content] =
      case Regex.split(~r/\<\%\=\s*\@inner_content\s*\%\>/, layout_file_contents) do
        [pre_inner_content, post_inner_content] ->
          [pre_inner_content, post_inner_content]

        [_layout_template] ->
          raise "The provided :mjml_layout must contain one <%= @inner_content %> expression."

        _ ->
          raise "The provided :mjml_layout contains multiple <%= @inner_content %> expressions."
      end

    quote do
      @external_resource unquote(mjml_layout)

      @doc false
      def pre_inner_content do
        unquote(pre_inner_content)
      end

      @doc false
      def post_inner_content do
        unquote(post_inner_content)
      end

      @doc false
      def __layout_file__ do
        unquote(mjml_layout)
      end
    end
  end
end
