defmodule MjmlEEx.LayoutTest do
  use ExUnit.Case, async: true

  # 1.0 twins of the 0.13 layout tests: layouts are template modules that render
  # {@inner_content}, and they can use the template's assigns

  defmodule BaseLayout do
    use MjmlEEx, template: "../templates/layouts/base.meex"
  end

  defmodule LayoutTemplate do
    use MjmlEEx, template: "../templates/layout_template.meex", layout: BaseLayout
  end

  defmodule AssignsLayout do
    use MjmlEEx, template: "../templates/layouts/assigns.meex"
  end

  defmodule AssignsLayoutTemplate do
    use MjmlEEx, template: "../templates/layout_template.meex", layout: AssignsLayout
  end

  # A function component as a layout, and a template written with ~MJML
  defmodule Layouts do
    use MjmlEEx.Component

    attr :title, :string, default: "Hello"

    def email(assigns) do
      ~MJML"""
      <mjml>
        <mj-head>
          <mj-title>{@title}</mj-title>
          <mj-attributes>
            <mj-class name="brand" color="#F45E43" />
          </mj-attributes>
        </mj-head>
        <mj-body>
          {@inner_content}
        </mj-body>
      </mjml>
      """
    end
  end

  defmodule SigilTemplate do
    use MjmlEEx, layout: {Layouts, :email}

    def render(assigns) do
      ~MJML"""
      <mj-section>
        <mj-column>
          <mj-text mj-class="brand">Hi {@name}</mj-text>
        </mj-column>
      </mj-section>
      """
    end
  end

  describe "telemetry" do
    test "reports the layout module and the file the template is in" do
      :telemetry.attach(
        "mjml_eex_layout_telemetry",
        [:mjml_eex, :render, :start],
        &__MODULE__.handle_telemetry/4,
        self()
      )

      LayoutTemplate.to_html(call_to_action_text: "Hi")
      assert_received {:start, %{module: LayoutTemplate, layout_module: BaseLayout, mjml_template_file: file}}
      assert file == Path.expand("../templates/layout_template.meex", __DIR__)

      SigilTemplate.to_html(name: "Alex")
      assert_received {:start, %{module: SigilTemplate, layout_module: Layouts, mjml_template_file: file}}
      assert file == __ENV__.file

      BaseLayout.to_html(inner_content: "")
      assert_received {:start, %{module: BaseLayout, layout_module: nil}}
    after
      :telemetry.detach("mjml_eex_layout_telemetry")
    end
  end

  def handle_telemetry(_event, _measurements, metadata, pid), do: send(pid, {:start, metadata})

  describe "LayoutTemplate" do
    test "raises if an assign is missing" do
      assert_raise ArgumentError, ~r/assign @call_to_action_text not available in template/, fn ->
        LayoutTemplate.to_html([])
      end
    end

    test "renders the template in the layout" do
      html = LayoutTemplate.to_html(call_to_action_text: "Click me please!")
      assert html =~ "Click me please!"
      assert html =~ "Say hello to card"
    end

    test "escapes assigns" do
      assert LayoutTemplate.to_html(call_to_action_text: "<script>alert('Hacked!');</script>Click me please!") =~
               "&lt;script&gt;alert(&#39;Hacked!&#39;);&lt;/script&gt;Click me please!"
    end

    test "render/1 returns the whole document" do
      mjml = [call_to_action_text: "Hi"] |> LayoutTemplate.render() |> MjmlEEx.to_mjml()
      assert mjml =~ ~r/^<mjml>\n  <mj-head>/
      assert mjml =~ ~s(<mj-body background-color="#F2F2F2">)
      assert :ok = MjmlEEx.validate(mjml)
    end
  end

  describe "AssignsLayoutTemplate" do
    test "the layout gets the template's assigns" do
      html = AssignsLayoutTemplate.to_html(call_to_action_text: "Click me please!", padding: "0px")
      assert html =~ "Click me please!"

      mjml = [call_to_action_text: "Hi", padding: "7px"] |> AssignsLayoutTemplate.render() |> MjmlEEx.to_mjml()
      assert mjml =~ ~s(<mj-section padding="7px"></mj-section>)
    end
  end

  describe "assigns" do
    defmodule TitleLayout do
      use MjmlEEx

      def render(assigns) do
        ~MJML"<mjml><mj-head><mj-title>{@title}</mj-title></mj-head><mj-body>{@inner_content}</mj-body></mjml>"
      end
    end

    defmodule DefaultsEmail do
      use MjmlEEx, layout: TitleLayout

      attr :title, :string, default: "Default title"

      def render(assigns), do: ~MJML"<mj-section><mj-column><mj-text>{@title}</mj-text></mj-column></mj-section>"
    end

    test "the layout gets the template's defaults" do
      mjml = %{} |> DefaultsEmail.render() |> MjmlEEx.to_mjml()
      assert mjml =~ "<mj-title>Default title</mj-title>"
      assert mjml =~ "<mj-text>Default title</mj-text>"
    end

    test "to_text/1 renders the email in its layout, and checks the assigns" do
      assert DefaultsEmail.to_text(%{}) == "Default title\n"
      assert DefaultsEmail.to_text(title: "Hi & welcome") == "Hi & welcome\n"
      assert_raise ArgumentError, ~r/attr :title/, fn -> DefaultsEmail.to_text(title: 42) end
    end
  end

  describe "function component layouts" do
    test "render the template, with the layout's defaults" do
      mjml = [name: "Alex"] |> SigilTemplate.render() |> MjmlEEx.to_mjml()
      assert mjml =~ "<mj-title>Hello</mj-title>"
      assert mjml =~ ~s(<mj-text mj-class="brand">Hi Alex</mj-text>)
      assert SigilTemplate.to_html(name: "Alex") =~ "Hi Alex"
    end
  end

  describe "validation" do
    defp compile(body, layout \\ "MjmlEEx.LayoutTest.BaseLayout") do
      Code.compile_string(
        """
        defmodule MjmlEEx.LayoutTest.Compiled#{System.unique_integer([:positive])} do
          use MjmlEEx, layout: #{layout}

          def render(assigns) do
            ~MJML\"\"\"
        #{String.replace(body, ~r/^/m, "    ")}
            \"\"\"
          end
        end
        """,
        "email.ex"
      )
    end

    test "the template is validated inside its layout" do
      error =
        assert_raise CompileError, fn ->
          compile("""
            <mj-body>
              <mj-text>Not in a section</mj-text>
            </mj-body>
          """)
        end

      assert Exception.message(error) =~
               "email.ex:7:9: mj-text cannot be used inside mj-body, only inside: mj-attributes, mj-column, mj-hero"
    end

    test "classes defined in the layout can be used" do
      assert [{_module, _}] =
               compile(
                 """
                   <mj-section><mj-column><mj-text mj-class="brand">Hi</mj-text></mj-column></mj-section>
                 """,
                 "{MjmlEEx.LayoutTest.Layouts, :email}"
               )

      assert_raise CompileError, ~r/mj-class missing is not defined in mj-attributes/, fn ->
        compile(
          """
            <mj-section><mj-column><mj-text mj-class="missing">Hi</mj-text></mj-column></mj-section>
          """,
          "{MjmlEEx.LayoutTest.Layouts, :email}"
        )
      end
    end

    test "a layout's includes are part of it" do
      dir = Path.join(System.tmp_dir!(), "mjml_eex_layout_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(Path.join(dir, "frame.meex"), "<mj-wrapper padding=\"10px\">{@inner_content}</mj-wrapper>")

      File.write!(
        Path.join(dir, "head.mjml"),
        ~s(<mj-attributes><mj-class name="brand" color="red" /></mj-attributes>)
      )

      File.write!(Path.join(dir, "layout.meex"), """
      <mjml>
        <mj-head><mj-include path="head.mjml" /></mj-head>
        <mj-body><mj-include path="frame.meex" /></mj-body>
      </mjml>
      """)

      Code.compile_string(
        "defmodule MjmlEEx.LayoutTest.IncludingLayout do\n  use MjmlEEx\nend",
        Path.join(dir, "layout.ex")
      )

      [{module, _}] =
        compile(
          ~s(<mj-section><mj-column><mj-text mj-class="brand">Hi</mj-text></mj-column></mj-section>),
          "MjmlEEx.LayoutTest.IncludingLayout"
        )

      assert module.to_html([]) =~ "Hi"

      # Classes from the layout's includes are known, so unknown ones are reported
      assert_raise CompileError, ~r/mj-class typo is not defined in mj-attributes/, fn ->
        compile(
          ~s(<mj-section><mj-column><mj-text mj-class="typo">Hi</mj-text></mj-column></mj-section>),
          "MjmlEEx.LayoutTest.IncludingLayout"
        )
      end
    end

    test "a layout can have a layout" do
      Code.compile_string("""
      defmodule MjmlEEx.LayoutTest.Middle do
        use MjmlEEx, layout: {MjmlEEx.LayoutTest.Layouts, :email}

        def render(assigns) do
          ~MJML\"\"\"
          <mj-section><mj-column><mj-text mj-class="brand">Header</mj-text></mj-column></mj-section>
          {@inner_content}
          \"\"\"
        end
      end
      """)

      [{module, _}] =
        compile(
          ~s(<mj-section><mj-column><mj-text mj-class="brand">Body</mj-text></mj-column></mj-section>),
          "MjmlEEx.LayoutTest.Middle"
        )

      html = module.to_html([])
      assert html =~ "Header"
      assert html =~ "Body"

      assert_raise CompileError, ~r/mj-text cannot be used inside mj-body/, fn ->
        compile("<mj-text>Not in a section</mj-text>", "MjmlEEx.LayoutTest.Middle")
      end
    end

    test "a problem in content the layout renders twice is reported once" do
      Code.compile_string("""
      defmodule MjmlEEx.LayoutTest.Twice do
        use MjmlEEx

        def render(assigns) do
          ~MJML\"\"\"
          <mjml><mj-body><%= if @wide do %><mj-wrapper>{@inner_content}</mj-wrapper><% else %>{@inner_content}<% end %></mj-body></mjml>
          \"\"\"
        end
      end
      """)

      error =
        assert_raise CompileError, fn ->
          compile(
            ~s(<mj-section><mj-column><mj-text colour="red">x</mj-text></mj-column></mj-section>),
            "MjmlEEx.LayoutTest.Twice"
          )
        end

      assert Exception.message(error) =~ "invalid MJML (1 error)"
    end

    test "private functions and layouts defined later can't be used" do
      Code.compile_string("""
      defmodule MjmlEEx.LayoutTest.Private do
        use MjmlEEx.Component
        def public(assigns), do: private(assigns)
        defp private(assigns), do: ~MJML"<mjml><mj-body>{@inner_content}</mj-body></mjml>"
      end
      """)

      assert_raise CompileError,
                   ~r/MjmlEEx.LayoutTest.Private.private\/1 can't be used as a layout: it's private/,
                   fn ->
                     compile("<mj-section />", "{MjmlEEx.LayoutTest.Private, :private}")
                   end

      assert_raise CompileError, ~r/the layout MjmlEEx.LayoutTest.Missing of .* isn't available/, fn ->
        compile("<mj-section />", "MjmlEEx.LayoutTest.Missing")
      end
    end

    test "a :layout that isn't a module or {module, function} raises" do
      assert_raise ArgumentError, ~r/the :layout option must be a module or \{module, function\}/, fn ->
        compile("<mj-section />", "{MjmlEEx.LayoutTest.BaseLayout, :render, :oops}")
      end

      assert_raise ArgumentError, ~r/the :layout option must be a module or \{module, function\}/, fn ->
        compile("<mj-section />", ~s("BaseLayout"))
      end
    end

    test "a layout must be an MJML EEx template that renders {@inner_content}" do
      assert_raise CompileError, ~r/the layout in test\/support\/components.ex doesn't render \{@inner_content\}/, fn ->
        compile("<mj-text>Hi</mj-text>", "{MjmlEEx.Test.Components, :data_row}")
      end

      assert_raise CompileError, ~r/can't be used as a layout: it isn't an MJML EEx template/, fn ->
        compile("<mj-text>Hi</mj-text>", "String")
      end

      assert_raise CompileError, ~r/doesn't render \{@inner_content\}/, fn ->
        compile("<mj-section></mj-section>", "{MjmlEEx.Test.Components, :head_block}")
      end
    end
  end
end
