defmodule MjmlEEx.TemplateValidationTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  setup do
    on_exit(fn ->
      Application.delete_env(:mjml_eex, :validation)
      Application.delete_env(:mjml_eex, :runtime_validation)
    end)
  end

  # Compiles a template module from a string, so each test gets fresh compile-time validation
  defp compile(name, body, file \\ "email.ex") do
    Code.compile_string(
      """
      defmodule MjmlEEx.TemplateValidationTest.#{name} do
        #{body}
      end
      """,
      file
    )
  after
    :code.purge(Module.concat(__MODULE__, name))
    :code.delete(Module.concat(__MODULE__, name))
  end

  @invalid_document ~S'''
    use MjmlEEx

    def render(assigns) do
      ~MJML"""
      <mjml>
        <mj-body>
          <mj-section>
            <mj-text colour="red">Hi {@name}</mj-text>
            <mj-column padding="10">
              <mj-image src={@src} fluid-on-mobile="yes" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
      """
    end
  '''

  describe "by default" do
    test "every problem fails compilation, with all of them listed" do
      error = assert_raise CompileError, fn -> compile(Strict, @invalid_document) end

      assert Exception.message(error) ==
               "email.ex:9: invalid MJML (4 errors):\n\n" <>
                 "    email.ex:9:11: mj-text cannot be used inside mj-section, only inside: mj-attributes, mj-column, mj-hero\n" <>
                 ~s(    email.ex:9:20: Attribute colour is illegal \(did you mean "color"?\)\n) <>
                 "    email.ex:10:22: Attribute padding has invalid value: 10 for type Unit, only accepts (px, %) units and 1 to 4 value(s)\n" <>
                 "    email.ex:11:34: Attribute fluid-on-mobile has invalid value: yes for type Boolean \n"
    end

    test "template files are validated too, with their own locations" do
      template = Path.expand("../templates/invalid.meex", __DIR__)

      error =
        assert_raise CompileError, fn ->
          compile(InvalidFile, ~s(use MjmlEEx, template: #{inspect(template)}))
        end

      assert Exception.message(error) =~ "invalid.meex:11:3: Element mj-bodyyyyyyyyyyyyyyyyyyyyyyyyyy doesn't exist"
    end
  end

  describe "levels" do
    test ":warn emits compiler warnings with the template location and compiles" do
      body = String.replace(@invalid_document, "use MjmlEEx", "use MjmlEEx, validation: :warn")

      {compiled, diagnostics} = Code.with_diagnostics(fn -> compile(Warn, body) end)

      assert [{_module, _binary}] = compiled
      assert Enum.any?(diagnostics, &(&1.message == ~s[Attribute colour is illegal (did you mean "color"?)]))

      assert Enum.map(diagnostics, &{&1.severity, &1.file, &1.position}) == [
               {:warning, "email.ex", {9, 11}},
               {:warning, "email.ex", {9, 20}},
               {:warning, "email.ex", {10, 22}},
               {:warning, "email.ex", {11, 34}}
             ]
    end

    test ":skip turns validation off" do
      assert capture_io(:stderr, fn ->
               compile(Skip, String.replace(@invalid_document, "use MjmlEEx", "use MjmlEEx, validation: :skip"))
             end) == ""
    end

    test "rules can be set one by one" do
      body =
        String.replace(
          @invalid_document,
          "use MjmlEEx",
          "use MjmlEEx, validation: [invalid_child: :skip, unknown_attribute: :warn, invalid_value: :skip]"
        )

      warnings = capture_io(:stderr, fn -> compile(PerRule, body) end)
      assert warnings =~ "Attribute colour is illegal"
      refute warnings =~ "cannot be used inside"
      refute warnings =~ "invalid value"
    end

    test "the application config applies, and templates override it" do
      Application.put_env(:mjml_eex, :validation, :skip)
      assert capture_io(:stderr, fn -> compile(GlobalSkip, @invalid_document) end) == ""

      Application.put_env(:mjml_eex, :validation, :warn)

      capture_io(:stderr, fn ->
        assert_raise CompileError, fn ->
          compile(
            TemplateOverride,
            String.replace(@invalid_document, "use MjmlEEx", "use MjmlEEx, validation: [invalid_value: :error]")
          )
        end
      end)
    end

    test "invalid settings are rejected" do
      assert_raise ArgumentError, ~r/invalid validation setting :loud/, fn ->
        compile(BadLevel, "use MjmlEEx, validation: :loud")
      end

      assert_raise ArgumentError, ~r/invalid validation setting {:typo, :warn}/, fn ->
        compile(BadRule, "use MjmlEEx, validation: [typo: :warn]")
      end
    end
  end

  describe "documents and fragments" do
    test "templates without an <mjml> root are validated as fragments" do
      body = ~S'''
        use MjmlEEx

        def render(assigns) do
          ~MJML"""
          <mjml><mj-body>{section(assigns)}</mj-body></mjml>
          """
        end

        def section(assigns) do
          ~MJML"""
          <mj-section><mj-column><mj-text>Hi</mj-text></mj-column></mj-section>
          """
        end

        def text(assigns), do: ~MJML"<mj-text>Hi</mj-text><mj-button href={@href}>Go</mj-button>"
      '''

      assert [{_module, _binary}] = compile(Fragments, body)
    end

    test "a self-closing <mjml /> is a document, as the formatter writes an empty one" do
      body = ~S'''
        use MjmlEEx

        def render(assigns), do: ~MJML"<mjml lang={@lang} />"
      '''

      assert [{module, _binary}] = compile(EmptyDocument, body)
      assert module.to_html(lang: "fr") =~ ~s(lang="fr")
    end

    test "fragments can be HTML, for components used inside ending tags" do
      body = ~S'''
        use MjmlEEx

        def link(assigns), do: ~MJML"<a href={@href}>{@label}</a>"
        def row(assigns), do: ~MJML"<tr><td>{@label}</td></tr>"
        def defaults(assigns), do: ~MJML"<mj-all padding='0' /><mj-class name='a' color='red' />"
        def render(assigns), do: ~MJML"<mj-text>Click <.link href='/' label='here' /></mj-text>"
      '''

      assert [{_module, _binary}] = compile(HtmlFragments, body)
    end

    test "mj-class names can come from a component in mj-head" do
      body = ~S'''
        use MjmlEEx

        def classes(assigns), do: ~MJML"<mj-attributes><mj-class name='blue' color='blue' /></mj-attributes>"

        def render(assigns) do
          ~MJML"""
          <mjml>
            <mj-head><.classes /></mj-head>
            <mj-body><mj-section><mj-column><mj-text mj-class="blue">x</mj-text></mj-column></mj-section></mj-body>
          </mjml>
          """
        end
      '''

      assert [{_module, _binary}] = compile(ComponentClasses, body)
    end

    test "alternative mj-heads and mj-bodies aren't duplicates" do
      body = ~S'''
        use MjmlEEx

        def render(assigns) do
          ~MJML"""
          <mjml>
            <mj-head :if={@dark}><mj-title>Dark</mj-title></mj-head>
            <mj-head :if={!@dark}><mj-title>Light</mj-title></mj-head>
            <%= if @wide do %>
              <mj-body width="800px"></mj-body>
            <% else %>
              <mj-body></mj-body>
            <% end %>
          </mjml>
          """
        end
      '''

      assert [{_module, _binary}] = compile(Alternatives, body)
    end

    test "fragments still check their own nesting" do
      body = ~S'''
        use MjmlEEx

        def render(assigns), do: ~MJML"<mj-section><mj-text>Hi</mj-text></mj-section>"
      '''

      assert_raise CompileError, ~r/mj-text cannot be used inside mj-section/, fn -> compile(BadFragment, body) end
    end

    test "the mj-class check is skipped when mj-head has expressions" do
      body = ~S'''
        use MjmlEEx

        def render(assigns) do
          ~MJML"""
          <mjml>
            <mj-head>{@shared_head}</mj-head>
            <mj-body><mj-section><mj-column><mj-text mj-class="brand">Hi</mj-text></mj-column></mj-section></mj-body>
          </mjml>
          """
        end
      '''

      assert [{_module, _binary}] = compile(DynamicHead, body)

      static_head = String.replace(body, "{@shared_head}", "<mj-title>Hi</mj-title>")

      assert_raise CompileError, ~r/mj-class brand is not defined in mj-attributes/, fn ->
        compile(StaticHead, static_head)
      end
    end
  end

  describe "runtime validation" do
    defmodule Dynamic do
      use MjmlEEx

      def render(assigns) do
        ~MJML"""
        <mj-text color={@color} {@rest}>Hi</mj-text>
        """
      end
    end

    defp render(assigns), do: assigns |> Dynamic.render() |> MjmlEEx.to_mjml()

    test "is off by default" do
      assert render(color: "nope", rest: [colour: "red"]) =~ ~s(color="nope")
    end

    test "raises with the template location when set to :raise" do
      Application.put_env(:mjml_eex, :runtime_validation, :raise)
      assert render(color: "#fff", rest: [padding: "10px"]) =~ ~s(color="#fff")

      error = assert_raise MjmlEEx.ValidationError, fn -> render(color: "nope", rest: []) end

      assert Exception.message(error) =~
               ~r/template_validation_test.exs:\d+:\d+: Attribute color has invalid value: nope for type Color/

      assert error.rule == :invalid_value

      assert_raise MjmlEEx.ValidationError, ~r/Attribute colour is illegal \(did you mean "color"\?\)/, fn ->
        render(color: nil, rest: [colour: "red"])
      end
    end

    test "logs when set to :warn" do
      Application.put_env(:mjml_eex, :runtime_validation, :warn)

      assert capture_log(fn -> assert render(color: "nope", rest: []) =~ ~s(color="nope") end) =~
               "Attribute color has invalid value"
    end
  end

  describe "MjmlEEx.validate/2" do
    test "uses the same levels" do
      mjml = ~s(<mj-text colour="red" align="middle">Hi</mj-text>)

      assert {:error, [%{rule: :unknown_attribute, severity: :error}, %{rule: :invalid_value, severity: :error}]} =
               MjmlEEx.validate(mjml, parent: "mj-column")

      assert {:error, [%{rule: :unknown_attribute, severity: :warn}]} =
               MjmlEEx.validate(mjml, parent: "mj-column", validation: [unknown_attribute: :warn, invalid_value: :skip])

      Application.put_env(:mjml_eex, :validation, :skip)
      assert :ok = MjmlEEx.validate(mjml, parent: "mj-column")
    end
  end
end
