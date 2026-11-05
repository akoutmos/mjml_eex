defmodule MjmlEExTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias MjmlEEx.Rendered
  alias MjmlEEx.Telemetry
  alias MjmlEEx.Test.Emails.Welcome

  # 1.0 twins of the 0.13 template tests. The templates still use EEx tags, which 1.0 keeps.

  defmodule BasicTemplate do
    use MjmlEEx, template: "templates/basic.meex"
  end

  defmodule ConditionalTemplate do
    use MjmlEEx, template: "templates/conditional.meex"
  end

  defmodule FunctionTemplate do
    use MjmlEEx, template: "templates/function.meex"

    defp generate_full_name(first_name, last_name), do: "#{first_name} #{last_name}"
  end

  defmodule MjmlEExTest.Gettext do
    use Gettext.Backend, otp_app: :mjml_eex
  end

  defmodule GettextTemplate do
    use MjmlEEx, template: "templates/gettext.meex"

    # Unlike 0.x, the import can come after `use MjmlEEx`
    use Gettext, backend: MjmlEExTest.Gettext
  end

  # Skips validation, which would reject the template at compile time, to test mjml_nif's error
  defmodule InvalidTemplate do
    use MjmlEEx, template: "templates/invalid.meex", validation: :skip
  end

  defmodule SigilTemplate do
    use MjmlEEx

    def render(assigns) do
      ~MJML"""
      <mjml>
        <mj-head>
          <mj-style>.cta a { text-decoration: none; }</mj-style>
        </mj-head>
        <mj-body>
          <mj-section :for={section <- @sections} css-class={section.class}>
            <mj-column>
              <mj-text color={section.color}>{section.title}</mj-text>
              <mj-image :if={section.image} src={section.image} fluid-on-mobile={section.fluid} />
            </mj-column>
          </mj-section>
          {footer(assigns)}
        </mj-body>
      </mjml>
      """
    end

    def footer(assigns) do
      ~MJML"""
      <mj-section>
        <mj-column>
          <mj-text>Sent by {@company}</mj-text>
        </mj-column>
      </mj-section>
      """
    end
  end

  def handle_telemetry(event, measurements, metadata, _opts) do
    send(self(), %{event: event, measurements: measurements, metadata: metadata})
  end

  describe "BasicTemplate" do
    test "raises if an assign is missing" do
      assert_raise ArgumentError, ~r/assign @call_to_action_text not available in template/, fn ->
        BasicTemplate.to_html([])
      end
    end

    test "renders the template with the assigns" do
      assert BasicTemplate.to_html(call_to_action_text: "Click me please!") =~ "Click me please!"
    end

    test "escapes assigns" do
      assert BasicTemplate.to_html(call_to_action_text: "<script>alert('Hacked!');</script> Click me please!") =~
               "&lt;script&gt;alert(&#39;Hacked!&#39;);&lt;/script&gt; Click me please!"
    end
  end

  describe "ConditionalTemplate" do
    test "renders the right branch" do
      assert ConditionalTemplate.to_html(all_caps: true) =~ "SIGN UP TODAY!!"
      assert ConditionalTemplate.to_html(all_caps: false) =~ "Sign up today!"
    end
  end

  describe "GettextTemplate" do
    test "can call gettext" do
      assert GettextTemplate.to_html([]) =~ "Hello John!"
    end
  end

  describe "FunctionTemplate" do
    test "can call private functions of the template module" do
      assert FunctionTemplate.to_html(first_name: "Alex", last_name: "Koutmos") =~ "Alex Koutmos"
    end

    test "escapes the function's result" do
      assert FunctionTemplate.to_html(first_name: "<script>alert('Hacked!');</script>", last_name: "Koutmos") =~
               "&lt;script&gt;alert(&#39;Hacked!&#39;);&lt;/script&gt; Koutmos"
    end
  end

  describe "InvalidTemplate" do
    test "raises when mjml_nif can't compile the MJML" do
      assert_raise RuntimeError,
                   ~r/Failed to compile MJML template: "unexpected element in root template at position/,
                   fn -> InvalidTemplate.to_html(call_to_action_text: "Hi") end
    end
  end

  describe "colocated templates" do
    test "render/1 comes from the .meex file next to the module" do
      rendered = Welcome.render(first_name: "Alex", cta_url: "https://example.com", items: ["a", "b"])

      assert %Rendered{} = rendered
      mjml = MjmlEEx.to_mjml(rendered)
      assert mjml =~ "<mj-title>Welcome, Alex</mj-title>"
      assert mjml =~ ~s(<mj-button href="https://example.com">Get started</mj-button>)
      assert mjml =~ "<mj-text>Item: a</mj-text><mj-text>Item: b</mj-text>"
    end

    test "to_html/1 accepts keyword lists and maps" do
      for assigns <- [[first_name: "Alex", cta_url: nil, items: []], %{first_name: "Alex", cta_url: nil, items: []}] do
        html = Welcome.to_html(assigns)
        assert html =~ "Welcome, Alex!"
        refute html =~ "Get started"
      end
    end

    test "the template file is tracked for recompilation" do
      assert Path.expand("support/emails/welcome.meex", __DIR__) in Welcome.__info__(:attributes)[:external_resource]
    end
  end

  describe "the ~MJML sigil" do
    @sections [
      %{class: "hero", color: "#ff0000", title: "One & two", image: "https://example.com/a.png", fluid: true},
      %{class: ["plain", nil, "wide"], color: nil, title: "Three", image: nil, fluid: false}
    ]

    test "renders :for, :if, attributes and nested templates" do
      mjml = %{sections: @sections, company: "Acme <Inc>"} |> SigilTemplate.render() |> MjmlEEx.to_mjml()

      assert mjml =~ ".cta a { text-decoration: none; }"
      assert mjml =~ ~s(<mj-section css-class="hero">)
      assert mjml =~ ~s(<mj-text color="#ff0000">One &amp; two</mj-text>)
      assert mjml =~ ~s(<mj-image src="https://example.com/a.png" fluid-on-mobile="true" />)
      assert mjml =~ ~s(<mj-section css-class="plain wide">)
      assert mjml =~ "<mj-text>Three</mj-text>"
      refute mjml =~ "fluid-on-mobile=\"false\""
      assert mjml =~ "Sent by Acme &lt;Inc&gt;"
      assert :ok = MjmlEEx.validate(mjml)
    end

    test "compiles to HTML" do
      html = SigilTemplate.to_html(sections: @sections, company: "Acme")
      assert html =~ "One &amp; two"
      assert html =~ "Sent by Acme"
    end

    test "requires assigns in scope" do
      assert_raise CompileError, ~r/~MJML requires a variable named "assigns"/, fn ->
        Code.compile_string("""
        defmodule NoAssigns do
          import MjmlEEx
          def render(_), do: ~MJML"<mjml></mjml>"
        end
        """)
      end
    end
  end

  describe "attributes" do
    import MjmlEEx
    import Phoenix.HTML, only: [raw: 1]

    defp render_mjml(template_fun, assigns), do: assigns |> template_fun.() |> MjmlEEx.to_mjml()

    test "nil and false omit the attribute; true is \"true\" on MJML tags and bare on HTML tags" do
      fun = fn assigns ->
        ~MJML"<mj-image alt={@a} title={@b} fluid-on-mobile={@c} /><mj-text><input d={@a} e={@b} f={@c}></mj-text>"
      end

      assert render_mjml(fun, %{a: nil, b: false, c: true}) ==
               ~s(<mj-image fluid-on-mobile="true" /><mj-text><input f></mj-text>)
    end

    test "attribute spreads" do
      fun = fn assigns -> ~MJML"<mj-text {@attrs}><a {@link}>x</a></mj-text>" end

      assert render_mjml(fun, %{
               attrs: [color: "red", padding: nil, "css-class": ["a", "b"]],
               link: %{href: "/x", hidden: true}
             }) ==
               ~s(<mj-text color="red" css-class="a b"><a hidden href="/x">x</a></mj-text>)
    end

    test "raw/1 skips escaping" do
      fun = fn assigns -> ~MJML"<mj-text>{raw(@html)} {@html}</mj-text>" end
      assert render_mjml(fun, %{html: "<b>x</b>"}) == "<mj-text><b>x</b> &lt;b&gt;x&lt;/b&gt;</mj-text>"
    end

    test "the mjml_eex attributes are removed" do
      fun = fn assigns ->
        ~MJML"<mj-raw mjml-raw-text><div></mj-raw><mj-text mjml-no-curly-interpolation>{@x}</mj-text>"
      end

      assert render_mjml(fun, %{}) == "<mj-raw><div></mj-raw><mj-text>{@x}</mj-text>"
    end
  end

  describe "errors" do
    test "use MjmlEEx rejects unknown options, such as 0.x's" do
      assert_raise ArgumentError, ~r/unknown keys \[:mjml_template\]/, fn ->
        Code.compile_string("defmodule OldOptions do\n  use MjmlEEx, mjml_template: \"a.mjml.eex\"\nend")
      end
    end

    test "template files are parsed at compile time" do
      template = Path.expand("templates/mismatched.meex", __DIR__)
      File.write!(template, "<mjml>\n  <mj-body>\n</mjml>\n")

      error =
        assert_raise MjmlEEx.ParseError, fn ->
          defmodule MismatchedTemplate do
            use MjmlEEx, template: "templates/mismatched.meex"
          end
        end

      assert {error.file, error.line, error.column} == {template, 3, 1}
      assert error.description =~ "unmatched closing tag. Expected </mj-body>"
    after
      File.rm(Path.expand("templates/mismatched.meex", __DIR__))
    end

    test "point to the template file, line and column" do
      error =
        assert_raise MjmlEEx.ParseError, fn ->
          Code.compile_string(
            """
            defmodule BrokenSigil do
              use MjmlEEx

              def render(assigns) do
                ~MJML\"\"\"
                <mj-section>
                  <mj-column>
                </mj-section>
                \"\"\"
              end
            end
            """,
            "broken_sigil.ex"
          )
        end

      assert {error.file, error.line, error.column} == {"broken_sigil.ex", 8, 5}

      # The snippet shows the template's lines with the file's line numbers
      assert error.description =~ """
             6 |     <mj-section>
             7 |       <mj-column>
             8 |     </mj-section>
               |     ^\
             """
    end

    test "point into expressions" do
      error =
        assert_raise TokenMissingError, fn ->
          Code.compile_string(
            """
            defmodule BrokenExpression do
              use MjmlEEx

              def render(assigns) do
                ~MJML\"\"\"
                <mj-text>{@name +}</mj-text>
                \"\"\"
              end
            end
            """,
            "broken_expression.ex"
          )
        end

      assert {error.file, error.line} == {"broken_expression.ex", 6}
    end

    test "point into single-line sigils" do
      error =
        assert_raise MjmlEEx.ParseError, fn ->
          Code.compile_string(
            """
            defmodule BrokenOneLiner do
              use MjmlEEx
              def render(assigns), do: ~MJML"<mj-text>{@x}</mj-button>"
            end
            """,
            "broken_one_liner.ex"
          )
        end

      assert {error.file, error.line, error.column} == {"broken_one_liner.ex", 3, 47}
    end

    test "a module needs render/1 or a template" do
      assert_raise CompileError,
                   ~r/needs a template: define render\/1 using the ~MJML sigil, or add a template file/,
                   fn ->
                     defmodule NoTemplate do
                       use MjmlEEx
                     end
                   end
    end

    test "a module can't have both render/1 and a template" do
      assert_raise CompileError, ~r/defines render\/1 and has a template at/, fn ->
        defmodule Both do
          use MjmlEEx, template: "templates/basic.meex"

          def render(assigns), do: ~MJML"<mjml>{@x}</mjml>"
        end
      end
    end

    test "a missing :template is reported" do
      assert_raise CompileError, ~r/the template .*does_not_exist.meex does not exist/, fn ->
        defmodule MissingTemplate do
          use MjmlEEx, template: "does_not_exist.meex"
        end
      end
    end
  end

  describe "MjmlEEx.to_html/2" do
    test "compiles rendered MJML and MJML strings" do
      rendered = Welcome.render(first_name: "Alex", cta_url: nil, items: [])
      assert MjmlEEx.to_html(rendered) == MjmlEEx.to_html(MjmlEEx.to_mjml(rendered))
      assert MjmlEEx.to_html(rendered) =~ "Welcome, Alex!"
    end
  end

  describe "telemetry" do
    test "to_html/1 emits render events" do
      Telemetry.attach_logger(level: :info)

      :telemetry.attach_many(
        "mjml_eex_test_telemetry",
        [[:mjml_eex, :render, :start], [:mjml_eex, :render, :stop]],
        &__MODULE__.handle_telemetry/4,
        nil
      )

      assert capture_log(fn -> Welcome.to_html(first_name: "Alex", cta_url: nil, items: []) end) =~ "Measurements:"

      assert_received %{event: [:mjml_eex, :render, :start], measurements: %{system_time: _}, metadata: metadata}

      for key <- [:compiler, :assigns, :mjml_template, :mjml_template_file, :layout_module] do
        assert Map.has_key?(metadata, key)
      end

      assert_received %{event: [:mjml_eex, :render, :stop], measurements: %{duration: _}, metadata: metadata}
      assert metadata.mjml_template =~ "<mj-title>Welcome, Alex</mj-title>"
      assert metadata.rendered_html =~ "Welcome, Alex!"
      assert metadata.mjml_template_file == Path.expand("support/emails/welcome.meex", __DIR__)
      assert metadata.module == Welcome
    after
      Telemetry.detach_logger()
      :telemetry.detach("mjml_eex_test_telemetry")
    end
  end
end
