defmodule MjmlEEx.EngineTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  # Template engine edge cases, compiled as real modules

  setup do
    on_exit(fn -> Application.delete_env(:mjml_eex, :runtime_validation) end)
  end

  defp compile(body, file \\ "email.ex", validation \\ :skip) do
    name = Module.concat(__MODULE__, "T#{System.unique_integer([:positive])}")

    [{module, _binary}] =
      Code.compile_string(
        """
        defmodule #{inspect(name)} do
          use MjmlEEx, validation: #{inspect(validation)}
          #{body}
        end
        """,
        file
      )

    module
  end

  defp sigil(template, validation \\ :skip) do
    compile(
      """
      def render(assigns) do
        ~MJML\"\"\"
        #{String.replace(template, "\n", "\n  ")}
        \"\"\"
      end
      """,
      "email.ex",
      validation
    )
  end

  defp render(module, assigns), do: assigns |> module.render() |> MjmlEEx.to_mjml()

  defp in_tmp_dir(files) do
    dir = Path.join(System.tmp_dir!(), "mjml_eex_engine_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    for {name, content} <- files, do: File.write!(Path.join(dir, name), content)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  describe "mjml-no-curly-interpolation" do
    test "ends with its tag when the content has void tags" do
      module =
        sigil(~S"""
        <mj-text mjml-no-curly-interpolation>Hi {{first_name}},<br>welcome<img src="a.png"></mj-text>
        <mj-text>Order {@order_id}</mj-text>
        """)

      assert render(module, order_id: 42) =~ "<mj-text>Order 42</mj-text>"
      assert render(module, order_id: 42) =~ "Hi {{first_name}},<br>welcome"
    end

    test "on a raw text tag only applies to that tag, whatever the order of the attributes" do
      for attrs <- ["mjml-no-curly-interpolation mjml-raw-text", "mjml-raw-text mjml-no-curly-interpolation"] do
        module =
          sigil("""
          <mj-raw #{attrs}><p>{{x}}</p></mj-raw>
          <mj-text>Order {@order_id}</mj-text>
          """)

        mjml = render(module, order_id: 42)
        assert mjml =~ "<mj-text>Order 42</mj-text>", "with #{attrs}"
        assert mjml =~ "<p>{{x}}</p>", "with #{attrs}"
      end
    end

    test "on a self-closing or void tag only applies to that tag" do
      module =
        sigil(~S"""
        <mj-image mjml-no-curly-interpolation src="a.png" />
        <img mjml-no-curly-interpolation src="b.png">
        <mj-text>Order {@order_id}</mj-text>
        """)

      assert render(module, order_id: 42) =~ "<mj-text>Order 42</mj-text>"
    end

    test "can't be an expression" do
      assert_raise MjmlEEx.ParseError, ~r/mjml-raw-text can't be an expression/, fn ->
        sigil(~S|<mj-raw mjml-raw-text={false}><p>x</p></mj-raw>|)
      end
    end
  end

  describe "interpolation" do
    test "accepts lists of rendered templates" do
      module =
        compile(~S'''
        def render(assigns) do
          ~MJML"""
          <mj-column>{Enum.map(@items, &row(%{item: &1}))}{if @more, do: [row(%{item: "c"}), "<d>"]}</mj-column>
          """
        end

        defp row(assigns), do: ~MJML"<mj-text>{@item}</mj-text>"
        ''')

      assert render(module, items: ["a", "b"], more: true) ==
               "<mj-column><mj-text>a</mj-text><mj-text>b</mj-text><mj-text>c</mj-text>&lt;d&gt;</mj-column>"
    end

    test "uppercase tags without a module get a syntax error" do
      error = assert_raise MjmlEEx.ParseError, fn -> sigil("<mj-text><B>Bold</B></mj-text>") end
      assert error.description =~ "invalid tag <B>. HTML tags are written in lowercase (<b>)"
    end

    test ":if and :for must be expressions" do
      assert_raise MjmlEEx.ParseError, ~r/:if must be an expression between \{...\}/, fn ->
        sigil(~s(<mj-text :if="nope">x</mj-text>))
      end
    end

    test "a byte order mark at the start of a template file is ignored" do
      dir = in_tmp_dir(%{"bom.meex" => "﻿<mjml><mj-body></mj-body></mjml>"})

      [{module, _}] =
        Code.compile_string("defmodule MjmlEEx.EngineTest.Bom do\n  use MjmlEEx\nend", Path.join(dir, "bom.ex"))

      assert render(module, []) == "<mjml><mj-body></mj-body></mjml>"
    end
  end

  describe "the ~MJML sigil" do
    test "accepts the noformat modifier" do
      module =
        compile(~S'''
        def render(assigns) do
          ~MJML"""
          <mj-text>{@name}</mj-text>
          """noformat
        end
        ''')

      assert render(module, name: "Alex") == "<mj-text>Alex</mj-text>"
    end

    test "rejects other modifiers" do
      assert_raise ArgumentError, ~r/~MJML only supports the noformat modifier, got: x/, fn ->
        compile(~S|def render(assigns), do: ~MJML"<mj-text />"x|)
      end
    end
  end

  describe "the template's Elixir code" do
    test "keeps {:safe, list} tuples as written" do
      module = sigil(~S|<mj-text>{Enum.join(Keyword.get([safe: ["a", "b"]], :safe), ",")}</mj-text>|)
      assert render(module, []) == "<mj-text>a,b</mj-text>"
    end
  end

  describe "attributes" do
    test "runtime validation accepts raw/1 values" do
      Application.put_env(:mjml_eex, :runtime_validation, :raise)
      module = sigil(~S|<mj-button href={raw(@url)} color={raw("nope!")}>Go</mj-button>|, [])

      assert_raise MjmlEEx.ValidationError, ~r/Attribute color has invalid value: nope!/, fn ->
        render(module, url: "https://example.com/?a=1&b=2")
      end
    end

    test "lists on MJML tags accept raw/1 values" do
      module = sigil(~S|<mj-text css-class={["a", raw("b&c"), nil]}>x</mj-text>|)
      assert render(module, []) == ~s(<mj-text css-class="a b&amp;c">x</mj-text>)
    end

    test "atom keys in spreads are dasherized on HTML tags, as in HEEx, and kept on MJML tags" do
      module = sigil(~S|<mj-text {[mj_class: "x"]}><a {[aria_label: "Close"]}>x</a></mj-text>|)
      assert render(module, []) == ~s(<mj-text mj_class="x"><a aria-label="Close">x</a></mj-text>)
    end

    test "a dynamic mj-font href keeps its & for the CSS @import" do
      module =
        sigil(
          ~S|<mjml><mj-head><mj-font name="Inter" href={@href} /></mj-head><mj-body><mj-section><mj-column><mj-text font-family="Inter">x</mj-text></mj-column></mj-section></mj-body></mjml>|
        )

      html = MjmlEEx.to_html(module.render(href: "https://fonts.example.com/css?family=Inter&family=Roboto"))

      assert html =~ "@import url(https://fonts.example.com/css?family=Inter&family=Roboto)"
    end

    test "a dynamic mj-font href can't break out of the CSS @import or the link tag" do
      module =
        sigil(
          ~S|<mjml><mj-head><mj-font name="Inter" {@attrs} /><mj-font name="Mono" href={@href} /></mj-head><mj-body><mj-section><mj-column><mj-text font-family="Inter">x</mj-text><mj-text font-family="Mono">y</mj-text></mj-column></mj-section></mj-body></mjml>|
        )

      payload = ~s|x.css);}</style><a href="https://evil.example">Verify</a><style>{a{|
      html = MjmlEEx.to_html(module.render(attrs: [href: payload], href: payload <> " 'x'\\"))

      refute html =~ "evil.example\""
      refute html =~ "<a href"
      refute html =~ "</style><a"

      assert html =~
               "@import url(x.css%29;%7D%3C/style%3E%3Ca%20href=%22https://evil.example%22%3EVerify%3C/a%3E%3Cstyle%3E%7Ba%7B)"

      assert html =~ "%7Ba%7B%20%27x%27%5C)"
    end

    test "obsolete void tags that mrml doesn't treat as void keep their slash" do
      module = sigil(~S|<mj-text><keygen /><br /></mj-text>|)
      assert render(module, []) == "<mj-text><keygen /><br></mj-text>"
    end
  end

  describe "assign helpers" do
    test "accept keyword lists, as render/1 can be called with one" do
      module = sigil(~S|<mj-text>{MjmlEEx.Component.assign_new(assigns, :name, fn -> "Alex" end).name}</mj-text>|)
      assert render(module, title: "x") == "<mj-text>Alex</mj-text>"
    end
  end

  describe "template files" do
    test "runtime errors in .meex templates point to the template" do
      dir = in_tmp_dir(%{"email.meex" => "<mj-section>\n\n<mj-text>{String.upcase(@name)}</mj-text>\n</mj-section>\n"})

      [{module, _}] =
        Code.compile_string(
          "defmodule MjmlEEx.EngineTest.Meex do\n  use MjmlEEx, validation: :skip\nend",
          Path.join(dir, "email.ex")
        )

      stacktrace =
        try do
          module.render(name: 1)
        rescue
          FunctionClauseError -> __STACKTRACE__
        end

      entry = Enum.find(stacktrace, &(elem(&1, 0) == module))
      assert entry |> elem(3) |> Keyword.get(:file) |> to_string() =~ "email.meex"
    end

    test "errors in included .meex files point into them" do
      dir =
        in_tmp_dir(%{
          "email.meex" => "<mjml><mj-body>\n<mj-include path=\"part.meex\" />\n</mj-body></mjml>\n",
          "part.meex" =>
            "<mj-section>\n  <mj-column>\n    <mj-text :for=\"x\">x</mj-text>\n  </mj-column>\n</mj-section>\n"
        })

      error =
        assert_raise MjmlEEx.ParseError, fn ->
          Code.compile_string("defmodule MjmlEEx.EngineTest.Part do\n  use MjmlEEx\nend", Path.join(dir, "email.ex"))
        end

      assert {Path.basename(error.file), error.line, error.column} == {"part.meex", 3, 14}
      assert error.description =~ ~s(3 |     <mj-text :for="x">x</mj-text>)
    end

    test ":if and :for can't be used on mj-include" do
      dir =
        in_tmp_dir(%{
          "email.meex" => "<mj-column>\n  <mj-include :if={@show} path=\"part.mjml\" />\n</mj-column>\n",
          "part.mjml" => "<mj-text>x</mj-text>"
        })

      error =
        assert_raise MjmlEEx.ParseError, fn ->
          Code.compile_string("defmodule MjmlEEx.EngineTest.Inc do\n  use MjmlEEx\nend", Path.join(dir, "email.ex"))
        end

      assert {error.line, error.column} == {2, 15}
      assert error.description =~ ":if can't be used on mj-include"
    end
  end

  describe "runtime validation" do
    test "logs with :warn" do
      Application.put_env(:mjml_eex, :runtime_validation, :warn)
      module = sigil(~S|<mj-button color={@c}>Go</mj-button>|, [])
      assert capture_log(fn -> render(module, c: "nope!") end) =~ "Attribute color has invalid value: nope!"
    end

    test "is off with false, nil and :skip, and raises for other unknown settings" do
      module = sigil(~S|<mj-button color={@c}>Go</mj-button>|, [])

      for off <- [false, nil, :skip] do
        Application.put_env(:mjml_eex, :runtime_validation, off)
        assert render(module, c: "nope!") =~ ~s(color="nope!")
      end

      for on <- [true, :raise, :error] do
        Application.put_env(:mjml_eex, :runtime_validation, on)
        assert_raise MjmlEEx.ValidationError, fn -> render(module, c: "nope!") end
      end

      Application.put_env(:mjml_eex, :runtime_validation, :off)

      assert_raise ArgumentError, ~r/invalid config :mjml_eex, runtime_validation: :off/, fn ->
        render(module, c: "nope!")
      end
    end

    test "follows the template's levels for its rules" do
      Application.put_env(:mjml_eex, :runtime_validation, :raise)
      template = ~S|<mj-button color={@c} {@attrs}>Go</mj-button>|

      skipped = sigil(template, invalid_value: :skip, unknown_attribute: :skip)
      assert render(skipped, c: "nope!", attrs: [data_x: "1"]) =~ ~s(color="nope!")

      warned = sigil(template, invalid_value: :warn)
      assert capture_log(fn -> render(warned, c: "nope!", attrs: []) end) =~ "Attribute color has invalid value: nope!"

      assert_raise MjmlEEx.ValidationError, ~r/Attribute data_x is illegal/, fn ->
        render(warned, c: "red", attrs: [data_x: "1"])
      end
    end
  end
end
