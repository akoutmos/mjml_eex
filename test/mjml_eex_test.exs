defmodule MjmlEExTest do
  use ExUnit.Case

  defmodule BasicTemplate do
    use MjmlEEx,
      mjml_template: "test_templates/basic_template.mjml.eex",
      mode: :compile
  end

  defmodule ConditionalTemplate do
    use MjmlEEx,
      mjml_template: "test_templates/conditional_template.mjml.eex",
      mode: :compile
  end

  defmodule ComponentTemplate do
    use MjmlEEx,
      mjml_template: "test_templates/component_template.mjml.eex",
      mode: :compile
  end

  defmodule DynamicComponentTemplate do
    use MjmlEEx,
      mjml_template: "test_templates/dynamic_component_template.mjml.eex",
      mode: :runtime
  end

  defmodule InvalidDynamicComponentTemplate do
    use MjmlEEx,
      mjml_template: "test_templates/invalid_dynamic_component_template.mjml.eex",
      mode: :runtime
  end

  defmodule FunctionTemplate do
    use MjmlEEx,
      mjml_template: "test_templates/function_template.mjml.eex",
      mode: :compile

    defp generate_full_name(first_name, last_name) do
      "#{first_name} #{last_name}"
    end
  end

  defmodule BaseLayout do
    @moduledoc false

    use MjmlEEx.Layout,
      mjml_layout: "test_layouts/base_layout.mjml.eex",
      mode: :compile
  end

  defmodule LayoutTemplate do
    use MjmlEEx,
      mjml_template: "test_templates/layout_template.mjml.eex",
      mode: :compile,
      layout: BaseLayout
  end

  defmodule AssignsLayout do
    @moduledoc false

    use MjmlEEx.Layout,
      mjml_layout: "test_layouts/assigns_layout.mjml.eex",
      mode: :compile
  end

  defmodule AssignsLayoutTemplate do
    use MjmlEEx,
      mjml_template: "test_templates/layout_template.mjml.eex",
      mode: :compile,
      layout: AssignsLayout
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
          use MjmlEEx,
            mjml_template: "test_templates/invalid_template.mjml.eex",
            mode: :compile
        end
      end
    end

    test "should raise an error if the MJML template compile mode is invalid" do
      assert_raise RuntimeError, ~r/:yolo is an invalid :mode. Possible values are :runtime or :compile/, fn ->
        defmodule InvalidCompileModeOption do
          use MjmlEEx,
            mjml_template: "test_templates/invalid_template.mjml.eex",
            mode: :yolo
        end
      end
    end

    test "should raise an error if the layout option is invalid" do
      assert_raise ArgumentError, ~r/could not load module InvalidModule due to reason/, fn ->
        defmodule InvalidLayoutOption do
          use MjmlEEx,
            mjml_template: "test_templates/invalid_template.mjml.eex",
            layout: InvalidModule
        end
      end
    end
  end

  describe "The use macro" do
    test "should fail to compile since a valid mjml template can not be found" do
      assert_raise RuntimeError, ~r/The provided :mjml_template does not exist at/, fn ->
        defmodule NoTemplateOption do
          use MjmlEEx
        end
      end
    end

    test "should fail to compile since the :mjml_template option points to a non-existent file" do
      assert_raise RuntimeError, ~r/The provided :mjml_template does not exist at/, fn ->
        defmodule NotFoundTemplateOption do
          use MjmlEEx,
            mjml_template: "does_not_exist.mjml.eex",
            mode: :compile
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

  describe "DynamicComponentTemplate.render/1" do
    test "should render the document with the appropriate assigns" do
      rendered_template = DynamicComponentTemplate.render(some_data: 1..5)

      assert rendered_template =~ "Some data - 1"
      assert rendered_template =~ "Some data - 2"
      assert rendered_template =~ "Some data - 3"
      assert rendered_template =~ "Some data - 4"
      assert rendered_template =~ "Some data - 5"
    end
  end

  describe "CompileTimeDynamicComponentTemplate.render/1" do
    test "should raise an error if a dynamic component is rendered at compile time" do
      assert_raise RuntimeError,
                   ~r/render_dynamic_component can only be used with runtime generated templates. Switch your template to `mode: :runtime`/,
                   fn ->
                     defmodule CompileTimeDynamicComponentTemplate do
                       use MjmlEEx,
                         mjml_template: "test_templates/dynamic_component_template.mjml.eex",
                         mode: :compile
                     end
                   end
    end
  end

  describe "InvalidDynamicComponentTemplate.render/1" do
    test "should raise an error as dynamic components cannot render other dynamic components" do
      assert_raise RuntimeError,
                   ~r/Cannot call `render_dynamic_component` inside of another dynamically rendered component/,
                   fn ->
                     InvalidDynamicComponentTemplate.render(some_data: 1..5)
                   end
    end
  end

  describe "BadExpressionDynamicComponentTemplate" do
    test "should fail to compile since the render_dynamic_component call is not in an = expression" do
      assert_raise RuntimeError,
                   ~r/render_dynamic_component can only be invoked inside of an <%= ... %> expression/,
                   fn ->
                     defmodule BadExpressionDynamicComponentTemplate do
                       use MjmlEEx,
                         mjml_template: "test_templates/bad_expression_dynamic_component_template.mjml.eex",
                         mode: :runtime
                     end
                   end
    end
  end

  describe "InvalidComponentTemplate" do
    test "should fail to compile since the render_static_component call is not in an = expression" do
      assert_raise RuntimeError,
                   ~r/render_static_component can only be invoked inside of an <%= ... %> expression/,
                   fn ->
                     defmodule InvalidTemplateOption do
                       use MjmlEEx,
                         mjml_template: "test_templates/invalid_component_template.mjml.eex",
                         mode: :compile
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

  describe "AssignsTemplate.render/1" do
    test "should raise an error if no assigns are provided" do
      assert_raise ArgumentError, ~r/assign @padding not available in template/, fn ->
        AssignsLayoutTemplate.render([])
      end
    end

    test "should render the template using a layout" do
      assert AssignsLayoutTemplate.render(call_to_action_text: "Click me please!", padding: "0px") =~ "Click me please!"
    end
  end

  describe "InvalidLayout" do
    test "should fail to compile since the layout contains no @inner_content expressions" do
      assert_raise RuntimeError, ~r/The provided :mjml_layout must contain one <%= @inner_content %> expression./, fn ->
        defmodule InvalidLayout do
          use MjmlEEx.Layout,
            mjml_layout: "test_layouts/invalid_layout.mjml.eex",
            mode: :compile
        end
      end
    end
  end

  describe "OtherInvalidLayout" do
    test "should fail to compile since the layout contains 2 @inner_content expressions" do
      assert_raise RuntimeError,
                   ~r/The provided :mjml_layout contains multiple <%= @inner_content %> expressions./,
                   fn ->
                     defmodule OtherInvalidLayout do
                       use MjmlEEx.Layout,
                         mjml_layout: "test_layouts/other_invalid_layout.mjml.eex",
                         mode: :compile
                     end
                   end
    end
  end

  describe "MissingOptionLayout" do
    test "should fail to compile since the use statement is missing a required option" do
      assert_raise RuntimeError, ~r/The :mjml_layout option is required./, fn ->
        defmodule MissingOptionLayout do
          use MjmlEEx.Layout
        end
      end
    end
  end

  describe "MissingFileLayout" do
    test "should fail to compile since the use statement is missing a required option" do
      assert_raise RuntimeError, ~r/The provided :mjml_layout does not exist at/, fn ->
        defmodule MissingFileLayout do
          use MjmlEEx.Layout,
            mode: :compile,
            mjml_layout: "invalid/path/to/layout.mjml.eex"
        end
      end
    end
  end
end
