defmodule MjmlIncludeTest do
  use ExUnit.Case, async: false

  alias MjmlEEx.Compilers.Rust
  alias MjmlEEx.Spec.Generated
  alias MjmlEEx.TagEngine.{Includes, Serializer}

  @include_dir Path.expand("test_includes", __DIR__)
  @fixtures_dir Path.expand("fixtures/includes", __DIR__)
  @mjml_results @fixtures_dir |> Path.join("mjml_includes.json") |> File.read!() |> JSON.decode!()
  @ending_tags for {name, %{ending_tag: true}} <- Generated.components(), do: name

  # mj-include is expanded when the template compiles, relative to the template's file
  defmodule IncludeTemplate do
    use MjmlEEx, template: "templates/include.meex"
  end

  defp render(body, name \\ "Alex") do
    {{:module, module, _, _}, _} =
      Code.eval_string(
        """
        defmodule MjmlIncludeTest.T#{System.unique_integer([:positive])} do
          use MjmlEEx
          def render(assigns), do: ~MJML'#{body}'
        end
        """,
        [],
        file: Path.join(@include_dir, "email.ex")
      )

    %{name: name} |> module.render() |> MjmlEEx.to_mjml()
  end

  # Our expansion in the shape spec_gen/includes.js gives MJML's: tags, attributes, the
  # trimmed content of ending tags, and child elements
  defp normalize({:block, :tag, name, attrs, children, _meta, _close}) do
    base = %{"tag" => name, "attributes" => Map.new(attrs, fn {attr, value, _} -> {attr, attribute_value(value)} end)}

    if name in @ending_tags do
      content = children |> Serializer.to_iodata() |> IO.iodata_to_binary() |> String.trim()
      Map.merge(base, %{"content" => content, "children" => []})
    else
      Map.put(base, "children", children |> Enum.filter(&element?/1) |> Enum.map(&normalize/1))
    end
  end

  defp normalize({:self_close, :tag, name, attrs, meta}), do: normalize({:block, :tag, name, attrs, [], meta, meta})

  defp element?(node), do: elem(node, 0) in [:block, :self_close]

  defp attribute_value({:string, value, _}), do: value
  defp attribute_value(nil), do: ""

  describe "compile-time expansion" do
    test "includes MJML files, including nested includes" do
      html = IncludeTemplate.to_html(name: "Alex")

      assert html =~ "Hello Alex!"
      assert html =~ "Included partial"
      assert html =~ "Nested partial"
    end

    test "tracks the included files for recompilation" do
      resources = IncludeTemplate.__info__(:attributes) |> Keyword.get_values(:external_resource) |> List.flatten()

      assert Path.join(@include_dir, "partial.mjml") in resources
      assert Path.join(@include_dir, "nested/nested.mjml") in resources
    end

    test ~s(inlines type="html" as mj-raw and adds type="css" to mj-head) do
      mjml =
        render(
          ~s(<mjml><mj-head><mj-title>T</mj-title></mj-head><mj-body><mj-include path="part.html" type="html" /><mj-include path="style.css" type="css" /></mj-body></mjml>)
        )

      assert mjml =~ ~s(<mj-raw><div class="raw">Raw <b>HTML</b></div>\n</mj-raw>)
      assert mjml =~ ~s(<mj-head><mj-title>T</mj-title><mj-style>.brand-text { color: blue; }\n</mj-style></mj-head>)
    end

    test "included content is validated, such as inline CSS that mjml_nif can't inline" do
      assert_raise CompileError, ~r/mjml_nif does not inline mj-style CSS/, fn ->
        render(~s(<mjml><mj-body><mj-include path="style.css" type="css" css-inline="inline" /></mj-body></mjml>))
      end
    end

    test "includes whole documents: the body in place, and the head into the document's head" do
      mjml = render(~s(<mjml><mj-body><mj-include path="full.mjml" /></mj-body></mjml>))

      assert mjml =~ ~s(<mj-text mj-class="brand">Full document</mj-text>)
      assert mjml =~ ~r/<\/mj-body><mj-head>\s*<mj-attributes><mj-class name="brand" color="#ff0000" \/>/
      assert :ok = MjmlEEx.validate(mjml)
    end

    test ".meex partials are templates" do
      mjml =
        render(
          ~s(<mjml><mj-body><mj-section><mj-column><mj-include path="greeting.meex" /></mj-column></mj-section></mj-body></mjml>)
        )

      assert mjml =~ "Hello Alex from a partial"
    end

    # mrml's own include loader renders included content differently from the same content
    # written in place (and doesn't support whole documents, nested includes at the top of a
    # file, or CSS in the body), so the expansion is checked against MJML's parser instead
    for fixture <- Path.wildcard(Path.join(@fixtures_dir, "*.mjml")) do
      @fixture fixture

      test "expands #{Path.basename(fixture)} like MJML does" do
        {nodes, _files} = @fixture |> File.read!() |> MjmlEEx.parse!() |> Includes.expand(@fixture)
        [root] = Enum.filter(nodes, &element?/1)

        assert normalize(root) == @mjml_results["fixtures"][Path.basename(@fixture)]
      end
    end
  end

  describe "errors" do
    test "missing files" do
      assert_raise MjmlEEx.ParseError, ~r/email.ex:3:\d+: mj-include can't read missing.mjml/, fn ->
        render(~s(<mjml><mj-body><mj-include path="missing.mjml" /></mj-body></mjml>))
      end
    end

    test "circular includes" do
      assert_raise MjmlEEx.ParseError, ~r/circular_b.mjml:1:1: mj-include of circular_a.mjml is circular/, fn ->
        render(~s(<mjml><mj-body><mj-include path="circular_a.mjml" /></mj-body></mjml>))
      end
    end

    test "dynamic paths" do
      assert_raise MjmlEEx.ParseError, ~r/the path of an mj-include must be a literal string/, fn ->
        render(~s(<mjml><mj-body><mj-include path={@path} /></mj-body></mjml>))
      end
    end

    test "head content in a fragment" do
      assert_raise MjmlEEx.ParseError, ~r/need a whole document with an <mjml> root/, fn ->
        render(~s(<mj-include path="style.css" type="css" />))
      end
    end

    test "validation errors point into the included file" do
      error =
        assert_raise CompileError, fn ->
          render(~s(<mjml><mj-body><mj-include path="invalid.mjml" /></mj-body></mjml>))
        end

      assert Exception.message(error) =~ "test/test_includes/invalid.mjml:3:14: Attribute colour is illegal"
    end
  end

  describe "the include_path compiler option" do
    setup do
      on_exit(fn -> Application.delete_env(:mjml_eex, :compiler_opts) end)
    end

    test "resolves mj-include in MJML strings given to MjmlEEx.to_html/2" do
      mjml = ~s(<mjml><mj-body><mj-include path="partial.mjml" /></mj-body></mjml>)

      assert MjmlEEx.to_html(mjml, include_path: @include_dir) =~ "Nested partial"

      Application.put_env(:mjml_eex, :compiler_opts, include_path: @include_dir)
      assert MjmlEEx.to_html(mjml) =~ "Nested partial"
    end

    test "resolves symlinks, which mjml_nif doesn't follow, as for an app's priv directory in dev" do
      link = Path.join(System.tmp_dir!(), "mjml_eex_include_link_#{System.unique_integer([:positive])}")
      File.ln_s!(@include_dir, link)
      on_exit(fn -> File.rm(link) end)

      mjml = ~s(<mjml><mj-body><mj-include path="partial.mjml" /></mj-body></mjml>)
      assert MjmlEEx.to_html(mjml, include_path: link) =~ "Nested partial"
    end

    test "can't be combined with include_loader" do
      assert_raise ArgumentError, ~r/only one of the :include_loader and :include_path/, fn ->
        Rust.mjml_opts(
          include_path: @include_dir,
          include_loader: %Mjml.ParserOptions.LocalIncludeLoader{path: @include_dir}
        )
      end
    end
  end
end
