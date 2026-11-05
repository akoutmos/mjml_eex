defmodule CompilerOptsTest do
  use ExUnit.Case, async: false

  alias MjmlEEx.Compilers.Rust

  defmodule OptionsTemplate do
    use MjmlEEx,
      template: "templates/options.meex",
      compiler_opts: [
        keep_comments: false,
        social_icon_path: "https://icons.example.com/",
        fonts: %{"Custom Font" => "https://fonts.example.com/custom-font.css"}
      ]
  end

  defmodule DefaultOptionsTemplate do
    use MjmlEEx, template: "templates/options.meex"
  end

  defmodule RuntimeOptionsTemplate do
    use MjmlEEx,
      template: "templates/options.meex",
      compiler_opts: [keep_comments: Application.get_env(:mjml_eex, :test_keep_comments, true)]
  end

  defmodule SingleArityCompiler do
    @behaviour MjmlEEx.Compiler

    @impl true
    def compile(mjml_template), do: {:ok, "compile/1: " <> mjml_template}
  end

  defmodule DoubleArityCompiler do
    @behaviour MjmlEEx.Compiler

    @impl true
    def compile(mjml_template, opts), do: {:ok, "compile/2: #{mjml_template} #{inspect(opts)}"}
  end

  setup do
    on_exit(fn ->
      Application.delete_env(:mjml_eex, :compiler_opts)
      Application.delete_env(:mjml_eex, :test_keep_comments)
      Application.put_env(:mjml_eex, :compiler, MjmlEEx.Compilers.Rust)
    end)
  end

  describe "MjmlEEx.compiler_opts/1" do
    test "should default to an empty list" do
      assert MjmlEEx.compiler_opts() == []
    end

    test "should merge the template options on top of the application config" do
      Application.put_env(:mjml_eex, :compiler_opts, timeout: 5_000, keep_comments: true)

      assert MjmlEEx.compiler_opts(keep_comments: false) == [timeout: 5_000, keep_comments: false]
    end
  end

  describe "MjmlEEx.Compiler.compile/3" do
    test "should call compile/1 when the compiler does not implement compile/2" do
      assert MjmlEEx.Compiler.compile(SingleArityCompiler, "<mjml />", keep_comments: false) ==
               {:ok, "compile/1: <mjml />"}
    end

    test "should pass the options to compile/2 when the compiler implements it" do
      assert MjmlEEx.Compiler.compile(DoubleArityCompiler, "<mjml />", keep_comments: false) ==
               {:ok, "compile/2: <mjml /> [keep_comments: false]"}
    end

    test "should pass the merged options when rendering a template" do
      Application.put_env(:mjml_eex, :compiler, DoubleArityCompiler)
      Application.put_env(:mjml_eex, :compiler_opts, timeout: 5_000, keep_comments: true)

      rendered = OptionsTemplate.to_html(name: "Alex")

      assert rendered =~ "compile/2: "
      assert rendered =~ ~s(timeout: 5000)
      assert rendered =~ ~s(keep_comments: false)
      refute rendered =~ ~s(keep_comments: true)
    end
  end

  describe "Rust compiler options" do
    test "should keep comments and use the default social icons by default" do
      rendered = DefaultOptionsTemplate.to_html(name: "Alex")

      assert rendered =~ "Hello Alex!"
      assert rendered =~ "MJML_EEX_TEST_COMMENT"
      assert rendered =~ "https://www.mailjet.com/images/theme/v1/icons/ico-social/github.png"
      refute rendered =~ "custom-font.css"
    end

    test "should apply the keep_comments, social_icon_path and fonts template options" do
      rendered = OptionsTemplate.to_html(name: "Alex")

      assert rendered =~ "Hello Alex!"
      refute rendered =~ "MJML_EEX_TEST_COMMENT"
      assert rendered =~ ~s(src="https://icons.example.com/github.png")
      assert rendered =~ "https://fonts.example.com/custom-font.css"
    end

    test "should apply options from the application config" do
      Application.put_env(:mjml_eex, :compiler_opts, keep_comments: false)

      refute DefaultOptionsTemplate.to_html(name: "Alex") =~ "MJML_EEX_TEST_COMMENT"
    end

    test "should evaluate the template options at render time" do
      assert RuntimeOptionsTemplate.to_html(name: "Alex") =~ "MJML_EEX_TEST_COMMENT"

      Application.put_env(:mjml_eex, :test_keep_comments, false)

      refute RuntimeOptionsTemplate.to_html(name: "Alex") =~ "MJML_EEX_TEST_COMMENT"
    end

    test "should accept fonts with atom keys or as a keyword list" do
      assert {:ok, html} = Rust.compile(font_template(), fonts: %{"Custom Font": "https://fonts.example.com/a.css"})
      assert html =~ "https://fonts.example.com/a.css"

      assert {:ok, html} = Rust.compile(font_template(), fonts: [{:"Custom Font", "https://fonts.example.com/b.css"}])
      assert html =~ "https://fonts.example.com/b.css"
    end

    test "should raise for invalid fonts" do
      assert_raise ArgumentError, ~r/:fonts compiler option must be a map or keyword list/, fn ->
        Rust.compile(font_template(), fonts: "https://fonts.example.com/a.css")
      end
    end

    test "should ignore unknown options" do
      assert Rust.mjml_opts(timeout: 5_000, path: "mjml", keep_comments: false) == [keep_comments: false]
    end
  end

  defp font_template do
    ~s(<mjml><mj-body><mj-section><mj-column><mj-text font-family="Custom Font">Hi</mj-text></mj-column></mj-section></mj-body></mjml>)
  end
end
