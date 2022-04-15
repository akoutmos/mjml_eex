defmodule MjmlEExTest do
  use ExUnit.Case

  defmodule BasicTemplate do
    use MjmlEEx, mjml_template: "test_templates/basic_template.mjml.eex"
  end

  defmodule ConditionalTemplate do
    use MjmlEEx, mjml_template: "test_templates/conditional_template.mjml.eex"
  end

  describe "BasicTemplate.render/1" do
    test "should raise an error if no assigns are provided" do
      assert_raise ArgumentError, ~r/assign @call_to_action_text not available in template/, fn ->
        BasicTemplate.render([])
      end
    end

    test "should render the template and contain the proper text when passed assigns" do
      assert BasicTemplate.render(call_to_action_text: "Click me please!") =~ "Click me please!"
    end
  end

  describe "ConditionalTemplate.render/1" do
    test "should output the correct button depending on the assigns" do
      assert ConditionalTemplate.render(all_caps: true) =~ "SIGN UP TODAY!!"
      assert ConditionalTemplate.render(all_caps: false) =~ "Sign up today!"
    end
  end

  describe "The use macro" do
    test "should fail to compile since a required option is not present" do
      assert_raise RuntimeError, ~r/The :mjml_template option is required./, fn ->
        defmodule NoTemplateOption do
          use MjmlEEx
        end
      end
    end

    test "should fail to compile since the :mjml_template option points to a non-existent file" do
      assert_raise RuntimeError, ~r/The provided :mjml_template does not exist at/, fn ->
        defmodule NotFoundTemplateOption do
          use MjmlEEx, mjml_template: "does_not_exist.mjml.eex"
        end
      end
    end
  end
end
