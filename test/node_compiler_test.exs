defmodule NodeCompilerTest do
  use ExUnit.Case, async: false

  defmodule BasicTemplate do
    use MjmlEEx,
      mjml_template: "test_templates/basic_template.mjml.eex"
  end

  setup_all do
    Application.ensure_started(:erlexec)
  end

  setup do
    path = System.get_env("MJML_CLI_PATH", "mjml")

    Application.put_env(:mjml_eex, :compiler, MjmlEEx.Compilers.Node)
    Application.put_env(:mjml_eex, :compiler_opts, path: path)
  end

  describe "BasicTemplate.render/1" do
    test "should render the template and contain the proper text when passed assigns" do
      Application.put_env(:mjml_eex, :compiler, MjmlEEx.Compilers.Node)

      assert BasicTemplate.render(call_to_action_text: "Click me please!") =~ "Click me please!"
    after
      set_default_config()
    end

    test "should raise an error if the timeout is set too low for rendering" do
      Application.put_env(:mjml_eex, :compiler, MjmlEEx.Compilers.Node)
      Application.put_env(:mjml_eex, :compiler_opts, timeout: 5)

      assert_raise RuntimeError,
                   ~r/Node mjml CLI compiler timed out after 0 second\(s\)/,
                   fn ->
                     BasicTemplate.render(call_to_action_text: "Click me please!")
                   end
    after
      set_default_config()
    end

    test "should raise an error if the mjml node cli tool is unavailable" do
      Application.put_env(:mjml_eex, :compiler, MjmlEEx.Compilers.Node)
      Application.put_env(:mjml_eex, :compiler_opts, path: "totally_not_a_real_cli_compiler")

      assert_raise RuntimeError,
                   ~r/Node mjml CLI compiler exited with status code 32512/,
                   fn ->
                     BasicTemplate.render(call_to_action_text: "Click me please!")
                   end
    after
      set_default_config()
    end
  end

  defp set_default_config do
    Application.put_env(:mjml_eex, :compiler, MjmlEEx.Compilers.Rust)
  end
end
