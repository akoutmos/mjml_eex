defmodule MjmlEExTest do
  use ExUnit.Case

  defmodule BasicTemplate do
    use MjmlEEx, mjml_template: "test_templates/basic_template.mjml.eex"
  end

  describe "BasicTemplate.render" do
    test "should raise an error if no assigns are provided" do
      assert_raise ArgumentError, ~r/assign @call_to_action_text not available in template/, fn ->
        BasicTemplate.render([])
      end
    end

    test "should render the template and contain the proper text when passed assigns" do
      assert BasicTemplate.render(call_to_action_text: "Click me please!") =~ "Click me please!"
    end
  end
end
