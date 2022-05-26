defmodule NodeCompilerTest do
  use ExUnit.Case, async: false

  defmodule BasicTemplate do
    use MjmlEEx,
      mjml_template: "test_templates/basic_template.mjml.eex"
  end

  describe "BasicTemplate.render/1" do
    test "should render the template and contain the proper text when passed assigns" do
      Application.put_env(MjmlEEx, :compiler, MjmlEEx.Compilers.Node)

      assert BasicTemplate.render(call_to_action_text: "Click me please!") =~ "Click me please!"
    after
      Application.put_env(MjmlEEx, :compiler, MjmlEEx.Compilers.Rust)
    end

    test "should raise an error if the timeout is set too low for rendering" do
      Application.put_env(MjmlEEx, :compiler, MjmlEEx.Compilers.Node)
      Application.put_env(MjmlEEx.Compilers.Node, :timeout, 5)

      assert_raise RuntimeError,
                   ~r/Node mjml CLI compiler timed out after 10 seconds/,
                   fn ->
                     BasicTemplate.render(call_to_action_text: "Click me please!")
                   end
    after
      Application.put_env(MjmlEEx, :compiler, MjmlEEx.Compilers.Rust)
      Application.delete_env(MjmlEEx.Compilers.Node, :timeout)
    end

    test "should raise an error if the mjml node cli tool is unavailable" do
      Application.put_env(MjmlEEx, :compiler, MjmlEEx.Compilers.Node)
      Application.put_env(MjmlEEx.Compilers.Node, :compiler_path, "totally_not_a_real_cli_compiler")

      assert_raise RuntimeError,
                   ~r/Node mjml CLI compiler exited with status code 32512/,
                   fn ->
                     BasicTemplate.render(call_to_action_text: "Click me please!")
                   end
    after
      Application.put_env(MjmlEEx, :compiler, MjmlEEx.Compilers.Rust)
      Application.delete_env(MjmlEEx.Compilers.Node, :compiler_path)
    end
  end
end
