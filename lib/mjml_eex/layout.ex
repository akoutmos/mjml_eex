defmodule MjmlEEx.Layout do
  @moduledoc """
  This module allows you to define a MJML layouts so that you
  can create reusable email skeletons.
  """

  @doc """
  Returns the MJML markup for the layout as a string.
  """
  @callback render(opts :: keyword()) :: String.t()

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
      @doc false
      def pre_inner_content do
        unquote(pre_inner_content)
      end

      @doc false
      def post_inner_content do
        unquote(post_inner_content)
      end
    end
  end
end
