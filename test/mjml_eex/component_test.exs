defmodule MjmlEEx.ComponentTest do
  use ExUnit.Case, async: true

  import MjmlEEx.Component, only: [assign: 3, assign_new: 3, assigns_to_attributes: 2]

  alias MjmlEEx.Component.Calls
  alias MjmlEEx.Test.Components

  # 1.0 twins of the 0.13 component tests: a static head block component (with a nested
  # component) and a component rendered in a loop with data from the assigns
  defmodule ComponentTemplate do
    use MjmlEEx, template: "../templates/component.meex"
    import MjmlEEx.Test.Components
  end

  defmodule Inline do
    use MjmlEEx
    import MjmlEEx.Test.Components

    def render(assigns) do
      ~MJML"""
      <mjml>
        <mj-body>
          <Components.table items={@items}>
            <:column width="30%" :let={item}>
              <mj-text>{item.name}</mj-text>
            </:column>
            <:column :if={@show_price} :let={%{price: price}}>
              <mj-text>${price}</mj-text>
            </:column>
          </Components.table>
          <mj-section>
            <mj-column>
              <.cta href="/go" {@cta_attrs}>Go <b>now</b></.cta>
              <.local_box :if={@show_box} />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
      """
    end

    attr :label, :string, default: "Box"

    defp local_box(assigns), do: ~MJML"<mj-text>{@label}</mj-text>"
  end

  defmodule WithAttrs do
    use MjmlEEx

    attr :name, :string, required: true
    attr :plan, :atom, values: [:free, :pro], default: :free
    attr :count, :integer, default: nil

    def render(assigns) do
      ~MJML"""
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hi {@name}, you're on {@plan}{if @count, do: " (#{@count})"}</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
      """
    end
  end

  describe "0.13 component templates" do
    test "render components, including nested and remote ones" do
      html = ComponentTemplate.to_html(some_data: 1..5)

      assert html =~ "Hello!"
      assert html =~ "Montserrat, Helvetica, Arial, sans-serif"
      for index <- 1..5, do: assert(html =~ "Some data - #{index}")
      assert html =~ "SIGN UP TODAY!!"
    end
  end

  describe "function components" do
    defp mjml(assigns), do: assigns |> Inline.render() |> MjmlEEx.to_mjml()

    @items [%{name: "Tea", price: 3}, %{name: "Cake", price: 5}]

    test "named slots with attributes, :let and :if" do
      mjml = mjml(items: @items, show_price: true, cta_attrs: [], show_box: false)

      assert mjml =~ ~s(<mj-column width="30%">)
      assert mjml =~ "<mj-text>Tea</mj-text>"
      assert mjml =~ "<mj-text>$3</mj-text>"
      assert mjml =~ "<mj-text>Cake</mj-text>"
      assert mjml =~ "<mj-text>$5</mj-text>"

      refute mjml(items: @items, show_price: false, cta_attrs: [], show_box: false) =~ "$3"
    end

    test "the inner block, :global attributes and spreads" do
      mjml = mjml(items: [], show_price: false, cta_attrs: [color: "#fff"], show_box: false)
      assert mjml =~ ~s(<mj-button href="/go" color="#fff">Go <b>now</b></mj-button>)
    end

    test "defaults and :if on private local components" do
      assert mjml(items: [], show_price: false, cta_attrs: [], show_box: true) =~ "<mj-text>Box</mj-text>"
      refute mjml(items: [], show_price: false, cta_attrs: [], show_box: false) =~ "Box"
    end

    test "render to valid MJML" do
      mjml = mjml(items: @items, show_price: true, cta_attrs: [color: "#fff"], show_box: true)
      assert :ok = MjmlEEx.validate(mjml)
      assert MjmlEEx.to_html(mjml) =~ "Cake"
    end

    test "import only the public API into the module" do
      imported =
        for {name, arity} <- MjmlEEx.Component.__info__(:functions) ++ MjmlEEx.Component.__info__(:macros),
            not String.starts_with?(Atom.to_string(name), "_"),
            do: {name, arity}

      assert Enum.sort(imported) == [
               assign: 3,
               assign_new: 3,
               assigns_to_attributes: 1,
               assigns_to_attributes: 2,
               attr: 2,
               attr: 3,
               render_slot: 1,
               render_slot: 2,
               slot: 1,
               slot: 2,
               slot: 3
             ]

      refute function_exported?(Components, :__components__, 0)
    end

    test "record their declarations" do
      assert %{cta: %{attrs: [%{name: :href, required: true}, %{name: :rest, type: :global, for: "mj-button"}]}} =
               Components.__mjml_eex_components__()

      assert %{table: %{slots: [%{name: :column, attrs: [%{name: :width, type: :string}]}]}} =
               Components.__mjml_eex_components__()
    end

    test "raise for a :let pattern that doesn't match" do
      defmodule BadLet do
        use MjmlEEx

        def render(assigns) do
          ~MJML"""
          <Components.table items={[1]}>
            <:column :let={%{name: name}}><mj-text>{name}</mj-text></:column>
          </Components.table>
          """
        end
      end

      assert_raise ArgumentError, ~r/cannot match the argument given to render_slot\/2 against the :let pattern/, fn ->
        BadLet.render(%{})
      end
    end

    test "raise if a component doesn't return rendered MJML" do
      defmodule NotRendered do
        use MjmlEEx

        def render(assigns), do: ~MJML"<.oops />"
        defp oops(_assigns), do: "<mj-text>oops</mj-text>"
      end

      assert_raise ArgumentError, ~r/to return rendered MJML \(use the ~MJML sigil\)/, fn -> NotRendered.render(%{}) end
    end
  end

  describe "attrs on template modules (D9)" do
    test "defaults are applied" do
      assert WithAttrs.to_html(name: "Alex") =~ "Hi Alex, you're on free"
      assert WithAttrs.to_html(name: "Alex", plan: :pro, count: 3) =~ "on pro (3)"
    end

    test "assigns are checked when rendering" do
      error = assert_raise ArgumentError, fn -> WithAttrs.to_html(plan: :gold, count: "three") end

      assert Exception.message(error) == """
             invalid assigns for MjmlEEx.ComponentTest.WithAttrs.to_html/1:

               * missing required attr :name
               * attr :plan must be one of [:free, :pro], got: :gold
               * attr :count must be of type :integer, got: "three"\
             """
    end

    test "declarations anywhere in a module apply to a template file's render/1" do
      {{:module, module, _, _}, _} =
        Code.eval_string("""
        defmodule MjmlEEx.ComponentTest.FileWithAttrs do
          use MjmlEEx, template: #{inspect(Path.expand("../templates/include.meex", __DIR__))}, validation: :skip
          attr :name, :string, required: true
        end
        """)

      assert %{render: %{attrs: [%{name: :name, required: true}]}} = module.__mjml_eex_components__()
      assert_raise ArgumentError, ~r/missing required attr :name/, fn -> module.to_html(%{}) end
    end
  end

  describe "call checks" do
    defp compile_call(name, body, opts \\ "") do
      Code.compile_string(
        """
        defmodule MjmlEEx.ComponentTest.#{name} do
          use MjmlEEx#{opts}
          alias MjmlEEx.Test.Components
          def render(assigns), do: ~MJML'#{body}'
        end
        """,
        "email.ex"
      )
    end

    test "report unknown and missing attributes, with suggestions" do
      error =
        assert_raise CompileError, fn ->
          compile_call(UnknownAttr, ~S|<Components.cta href="/" colour="red" padding-top="9">Go</Components.cta>|)
        end

      assert Exception.message(error) == """
             email.ex:4: invalid component call (2 errors):

                 email.ex:4:59: unknown attribute colour for <Components.cta> (did you mean "color"?)
                 email.ex:4:72: Attribute padding-top has invalid value: 9 for type Unit, only accepts (px, %) units and 1 value(s) (for <Components.cta>)

             To allow them, set their rules to :warn or :skip, for the whole app or for one module:

                 config :mjml_eex, validation: [unknown_attribute: :warn, invalid_value: :warn]
                 use MjmlEEx, validation: [unknown_attribute: :warn, invalid_value: :warn]
             """

      assert_raise CompileError, ~r/missing required attribute href for <Components.cta>/, fn ->
        compile_call(MissingAttr, "<Components.cta>Go</Components.cta>")
      end
    end

    test "check literal values against types and :values" do
      assert_raise CompileError, ~r/attribute title for <Components.head_block> must be of type :string, got: 3/, fn ->
        compile_call(WrongType, "<Components.head_block title={3} />")
      end

      assert [{_module, _}] = compile_call(ExpressionValue, "<Components.head_block title={@title} />")
    end

    test "report undefined and missing slots, and slot attributes" do
      error =
        assert_raise CompileError, fn ->
          compile_call(
            BadSlots,
            ~S|<Components.table items={[]}><:colum>x</:colum><:column width={30}>y</:column></Components.table>|
          )
        end

      assert Exception.message(error) =~ ~s[undefined slot colum for <Components.table> (did you mean "column"?)]

      assert Exception.message(error) =~
               "attribute width for <:column> in <Components.table> must be of type :string, got: 30"

      assert_raise CompileError, ~r/missing required slot inner_block for <Components.cta>/, fn ->
        compile_call(NoInner, ~S|<Components.cta href="/" />|)
      end
    end

    test "accept the names a global attr includes, whatever its for: tag accepts" do
      assert [{_module, _}] =
               compile_call(Included, ~S|<Components.section data-section="hero">x</Components.section>|)
    end

    test "report slots a component doesn't declare when it declares attrs" do
      assert_raise CompileError, ~r/undefined slot bogus for <Components.data_row>/, fn ->
        compile_call(UndeclaredSlot, ~S|<Components.data_row data="x"><:bogus>y</:bogus></Components.data_row>|)
      end
    end

    test "skip missing attributes when there's a spread" do
      assert [{_module, _}] = compile_call(Spread, "<Components.cta {@attrs}>Go</Components.cta>")
    end

    test "report attributes passed through a :global that mjml_nif ignores or handles differently" do
      assert_raise CompileError, ~r/mjml_nif ignores the title attribute of mj-button \(for <Components.cta>\)/, fn ->
        compile_call(IgnoredGlobal, ~S|<Components.cta href="/" title="Go">Go</Components.cta>|)
      end

      assert_raise CompileError, ~r/mjml_nif treats full-width="false" as full width/, fn ->
        compile_call(FullWidthGlobal, ~S|<Components.section full-width="false" />|)
      end

      assert [{_module, _}] =
               compile_call(
                 IgnoredGlobalSkipped,
                 ~S|<Components.cta href="/" title="Go">Go</Components.cta>|,
                 ", validation: [unsupported_value: :skip]"
               )
    end

    test "follow the validation levels" do
      assert [{_module, _}] =
               compile_call(
                 Lenient,
                 ~S|<Components.head_block colour="red" />|,
                 ", validation: [component_attribute: :skip]"
               )

      # Attributes passed to the MJML tag of a :global attribute are checked with the rules for
      # MJML attributes
      assert [{_module, _}] =
               compile_call(
                 LenientGlobal,
                 ~S|<Components.cta href="/" colour="red" padding-top="9">Go</Components.cta>|,
                 ", validation: [unknown_attribute: :skip, invalid_value: :skip]"
               )

      assert_raise CompileError, ~r/unknown attribute colour for <Components.cta>/, fn ->
        compile_call(
          StrictGlobal,
          ~S|<Components.cta href="/" colour="red">Go</Components.cta>|,
          ", validation: [component_attribute: :skip]"
        )
      end
    end

    test "calls to components defined later in the module are checked after the module compiles" do
      [{module, _}] =
        Code.compile_string(
          """
          defmodule MjmlEEx.ComponentTest.Later do
            use MjmlEEx
            def render(assigns), do: ~MJML"<.later size={@size} />"
            attr :size, :string, values: ["small", "large"]
            defp later(assigns), do: ~MJML"<mj-text>{@size}</mj-text>"
          end
          """,
          "email.ex"
        )

      assert [%{fun: :later, display: "<.later>", line: 3}] = module.__mjml_eex_calls__()
      assert :ok = Calls.__verify__(module)

      [call] = module.__mjml_eex_calls__()
      bad_call = %{call | attrs: [{:size, 3, 40, {:literal, "big"}}]}

      assert [%{message: ~s(attribute size for <.later> must be one of ["small", "large"], got: "big")}] =
               Calls.check(bad_call, %{
                 attrs: [%{name: :size, type: :string, values: ["small", "large"], required: false, default: :none}],
                 slots: []
               })
    end
  end

  describe "changing a component" do
    setup do
      Code.put_compiler_option(:ignore_module_conflict, true)
      on_exit(fn -> Code.put_compiler_option(:ignore_module_conflict, false) end)
    end

    defp compile_button(attrs) do
      Code.compile_string("""
      defmodule MjmlEEx.ComponentTest.Changing do
        use MjmlEEx.Component
        #{attrs}
        def button(assigns), do: ~MJML"<mj-button>Go</mj-button>"
      end
      """)
    end

    test "rechecks the calls to it that were checked when their template compiled" do
      compile_button(~S|attr :href, :string|)

      [{email, _}] =
        Code.compile_string(
          """
          defmodule MjmlEEx.ComponentTest.CallsChanging do
            use MjmlEEx
            def render(assigns), do: ~MJML"<MjmlEEx.ComponentTest.Changing.button href='/' />"
          end
          """,
          "email.ex"
        )

      assert :ok = Calls.__verify__(email)

      # Elixir runs @after_verify again when a module the template calls changes
      compile_button("attr :href, :string\nattr :label, :string, required: true")

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          assert_raise CompileError, ~r/invalid component calls/, fn -> Calls.__verify__(email) end
        end)

      assert output =~ "missing required attribute label for <MjmlEEx.ComponentTest.Changing.button>"
    end
  end

  describe "declaration errors" do
    test "invalid types and options" do
      assert_raise CompileError, ~r/invalid type :text for attr :name/, fn ->
        Code.eval_string(
          "defmodule BadType do\n use MjmlEEx.Component\n attr :name, :text\n def x(assigns), do: assigns\nend"
        )
      end

      assert_raise CompileError, ~r/invalid options \[:size\] for attr :name/, fn ->
        Code.eval_string(
          "defmodule BadOpt do\n use MjmlEEx.Component\n attr :name, :string, size: 3\n def x(assigns), do: assigns\nend"
        )
      end

      assert_raise CompileError, ~r/can't be both required and have a default/, fn ->
        Code.eval_string(
          "defmodule BadReq do\n use MjmlEEx.Component\n attr :name, :string, required: true, default: \"x\"\n def x(assigns), do: assigns\nend"
        )
      end
    end

    test "declarations need a function that takes assigns" do
      assert_raise CompileError, ~r/attrs and slots must be followed by a function definition/, fn ->
        Code.eval_string("defmodule Dangling do\n use MjmlEEx.Component\n attr :name, :string\nend")
      end

      assert_raise CompileError, ~r/only be declared on functions that take assigns, but x\/2 doesn't/, fn ->
        Code.eval_string(
          "defmodule TwoArgs do\n use MjmlEEx.Component\n attr :name, :string\n def x(a, b), do: {a, b}\nend"
        )
      end
    end

    test "options that don't fit together" do
      declarations = [
        {~S|attr :name, :string, for: "mj-text"|, "the :for and :include options are only for :global attrs"},
        {~S|attr :rest, :global, for: "mj-buton"|, ~S|must be an MJML tag, such as "mj-button", got: "mj-buton"|},
        {~S|attr :size, :integer, default: "big"|, ~S|the default of attr :size must be of type :integer, got: "big"|},
        {~S|attr :size, :string, values: ["s", "l"], default: "m"|, "must be one of [\"s\", \"l\"], got: \"m\""},
        {"attr :rest, :global\nattr :other, :global", "a component can only have one :global attr"},
        {"slot :col do\nattr :width, :string, default: \"50%\"\nend", "slot attr :width can't have a default"},
        {"slot :col do\nattr :rest, :global\nend", "slot attr :rest can't be :global"}
      ]

      for {declaration, message} <- declarations do
        error =
          assert_raise CompileError, fn ->
            Code.eval_string(
              "defmodule BadDeclaration do\n use MjmlEEx.Component\n #{declaration}\n def x(assigns), do: assigns\nend"
            )
          end

        assert Exception.message(error) =~ message
      end
    end

    test "use MjmlEEx.Component takes a validation option" do
      assert {{:module, _, _, _}, _} =
               Code.eval_string("""
               defmodule LenientComponents do
                 use MjmlEEx.Component, validation: [unknown_tag: :skip]
                 def x(assigns), do: ~MJML"<mj-nope />"
               end
               """)

      assert_raise ArgumentError, ~r/the :mode option was removed/, fn ->
        Code.eval_string("defmodule ModeComponents do\n use MjmlEEx.Component, mode: :runtime\nend")
      end
    end

    test ":let needs inner content" do
      assert_raise MjmlEEx.ParseError, ~r/cannot use :let on a component without inner content/, fn ->
        Code.eval_string(
          "defmodule LetSelfClose do\n use MjmlEEx\n def render(assigns), do: ~MJML\"<.x :let={y} />\"\nend"
        )
      end
    end
  end

  describe "template files" do
    test "declarations before a def render(assigns) head apply to the template" do
      dir = Path.join(System.tmp_dir!(), "mjml_eex_head_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      File.write!(Path.join(dir, "email.meex"), "<mj-text>{@name} {@plan} {double(2)}</mj-text>")

      [{module, _}] =
        Code.compile_string(
          """
          defmodule MjmlEEx.ComponentTest.Head do
            use MjmlEEx, validation: :skip

            def double(x), do: x * 2

            attr :name, :string, required: true
            attr :plan, :atom, values: [:free, :pro], default: :free
            def render(assigns)
          end
          """,
          Path.join(dir, "email.ex")
        )

      assert [name: "Alex"] |> module.render() |> MjmlEEx.to_mjml() == "<mj-text>Alex free 4</mj-text>"
      assert_raise ArgumentError, ~r/missing required attr :name/, fn -> module.to_html([]) end
    end
  end

  describe "assign helpers" do
    test "assign, assign_new and assigns_to_attributes" do
      assigns = %{a: 1, inner_block: [%{__slot__: :inner_block}], col: [%{__slot__: :col}], __changed__: nil}

      assert assign(assigns, :b, 2).b == 2
      assert assign_new(assigns, :a, fn -> 5 end).a == 1
      assert assign_new(assigns, :b, fn %{a: a} -> a + 1 end).b == 2
      assert assigns_to_attributes(Map.put(assigns, :c, 3), [:c]) == [a: 1]
    end
  end
end
