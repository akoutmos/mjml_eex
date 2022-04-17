defmodule MjmlEExTest do
  use ExUnit.Case

  defmodule BasicTemplate do
    use MjmlEEx, mjml_template: "test_templates/basic_template.mjml.eex"
  end

  defmodule ConditionalTemplate do
    use MjmlEEx, mjml_template: "test_templates/conditional_template.mjml.eex"
  end

  defmodule ComponentTemplate do
    use MjmlEEx, mjml_template: "test_templates/component_template.mjml.eex"
  end

  defmodule FunctionTemplate do
    use MjmlEEx, mjml_template: "test_templates/function_template.mjml.eex"

    defp generate_full_name(first_name, last_name) do
      "#{first_name} #{last_name}"
    end
  end

  defmodule BaseLayout do
    @moduledoc false

    use MjmlEEx.Layout, mjml_layout: "test_layouts/base_layout.mjml.eex"
  end

  defmodule LayoutTemplate do
    use MjmlEEx,
      mjml_template: "test_templates/layout_template.mjml.eex",
      layout: BaseLayout
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

  describe "FunctionTemplate.render/1" do
    test "should output the correct output when a module function is used" do
      assert FunctionTemplate.render(first_name: "Alex", last_name: "Koutmos") =~ "Alex Koutmos"
    end
  end

  describe "ErrorTemplate" do
    test "should raise an error if the MJML template fails to compile" do
      assert_raise RuntimeError, ~r/Failed to compile MJML template: \"unexpected element at position 448\"/, fn ->
        defmodule InvalidTemplateOption do
          use MjmlEEx, mjml_template: "test_templates/invalid_template.mjml.eex"
        end
      end
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

  describe "ComponentTemplate.render/1" do
    test "should render the document with the head and attribute block" do
      assert ComponentTemplate.render(all_caps: true) =~ "SIGN UP TODAY!!"
      assert ComponentTemplate.render(all_caps: true) =~ "Montserrat, Helvetica, Arial, sans-serif"
    end
  end

  describe "InvalidComponentTemplate" do
    test "should fail to compile since the render_component call is not in an = expression" do
      assert_raise RuntimeError, ~r/render_component can only be invoked inside of an <%= ... %> expression/, fn ->
        defmodule InvalidTemplateOption do
          use MjmlEEx, mjml_template: "test_templates/invalid_component_template.mjml.eex"
        end
      end
    end
  end

  describe "LayoutTemplate.render/1" do
    test "should raise an error if no assigns are provided" do
      assert_raise ArgumentError, ~r/assign @call_to_action_text not available in template/, fn ->
        LayoutTemplate.render([])
      end
    end

    test "should render the template using a layout" do
      assert LayoutTemplate.render(call_to_action_text: "Click me please!") =~ "Click me please!"
    end
  end

  describe "InvalidLayoutTemplate" do
    test "should fail to compile since the layout contains no @inner_content expressions" do
      assert_raise RuntimeError, ~r/The provided :mjml_layout must contain one <%= @inner_content %> expression./, fn ->
        defmodule InvalidLayout do
          use MjmlEEx.Layout, mjml_layout: "test_layouts/invalid_layout.mjml.eex"
        end
      end
    end
  end

  describe "OtherInvalidLayoutTemplate" do
    test "should fail to compile since the layout contains 2 @inner_content expressions" do
      assert_raise RuntimeError,
                   ~r/The provided :mjml_layout contains multiple <%= @inner_content %> expressions./,
                   fn ->
                     defmodule OtherInvalidLayout do
                       use MjmlEEx.Layout, mjml_layout: "test_layouts/other_invalid_layout.mjml.eex"
                     end
                   end
    end
  end
end
