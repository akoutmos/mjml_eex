defmodule MjmlEEx.TagEngine.ParserTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import ExUnit.CaptureIO

  alias MjmlEEx.ParseError
  alias MjmlEEx.TagEngine.{Parser, Serializer}

  defp parse!(source, opts \\ []), do: Parser.parse!(source, opts)

  describe "template mode" do
    test "parses interpolation in text and attribute values" do
      assert [{:block, :tag, "mj-text", [{"color", {:expr, "@color", _}, _}], children, _, _}] =
               parse!(~s(<mj-text color={@color}>Hi {@name}!</mj-text>))

      assert [{:text, "Hi ", _}, {:body_expr, "@name", %{line: 1, column: 28}}, {:text, "!", _}] = children
    end

    test "parses EEx expressions and blocks" do
      assert [{:block, :tag, "mj-column", [], children, _, _}] =
               parse!("<mj-column><%= if @show do %><mj-text><%= @name %></mj-text><% end %></mj-column>")

      assert [{:eex_block, "if @show do", [{[{:block, :tag, "mj-text", [], [{:eex, "@name", _}], _, _}], "end", _}], _}] =
               children
    end

    test "keeps :if and :for as attributes" do
      assert [{:block, :tag, "mj-text", [{":if", {:expr, "@show", _}, _}], _, %{special: [":if"]}, _}] =
               parse!(~s(<mj-text :if={@show}>Hi</mj-text>))
    end

    test "parses function components and slots" do
      assert [{:block, :local_component, "footer", _, [{:block, :slot, "note", [], _, _, _}], _, _}] =
               parse!(~s(<.footer company={@company}><:note>Hi</:note></.footer>))

      assert [{:self_close, :remote_component, "MyApp.Emails.footer", _, _}] = parse!(~s(<MyApp.Emails.footer />))
    end

    test "does not interpolate in mj-style, style and script" do
      for tag <- ~w(mj-style style script) do
        css = ".a { color: red; } @media (max-width: 480px) { .a { color: {blue}; } }"
        assert [{:block, :tag, ^tag, [], [{:text, ^css, _}], _, _}] = parse!("<#{tag}>#{css}</#{tag}>")
      end
    end

    test "parses mj-raw content as HTML by default" do
      assert [{:block, :tag, "mj-raw", [], [{:block, :tag, "div", _, [{:body_expr, "@x", _}], _, _}], _, _}] =
               parse!(~s(<mj-raw><div class="a">{@x}</div></mj-raw>))

      assert_raise ParseError, ~r/unmatched closing tag/, fn -> parse!(~s(<mj-raw><div></mj-raw>)) end
    end

    test "parses mj-raw content as raw text with mjml-raw-text" do
      assert [
               {:block, :tag, "mj-raw", [{"mjml-raw-text", nil, _}], [{:text, "<div>{@x}", _}], _, _},
               {:block, :tag, "mj-raw", [{"mjml-raw-text", nil, _}], [{:text, "</div>", _}], _, _}
             ] = parse!(~s(<mj-raw mjml-raw-text><div>{@x}</mj-raw><mj-raw mjml-raw-text></div></mj-raw>))
    end

    test "disables curly interpolation with mjml-no-curly-interpolation" do
      assert [{:block, :tag, "mj-text", _, [{:text, "{not an expression}", _}], _, _}] =
               parse!(~s(<mj-text mjml-no-curly-interpolation>{not an expression}</mj-text>))
    end

    test "mj-* tags are never void and may self-close; HTML void tags don't need closing" do
      assert [{:self_close, :tag, "mj-image", _, %{closing: :self}}] = parse!(~s(<mj-image src="a.png" />))
      assert_raise ParseError, ~r/without closing tag for <mj-image>/, fn -> parse!(~s(<mj-image src="a.png">)) end

      assert [
               {:block, :tag, "mj-text", [], [{:text, "a", _}, {:self_close, :tag, "br", [], %{closing: :void}}, _], _,
                _}
             ] =
               parse!(~s(<mj-text>a<br>b</mj-text>))
    end

    test "keeps comments, including conditional comments, as text" do
      source = "<mj-raw><!--[if mso]><table><![endif]--></mj-raw>"
      assert [{:block, :tag, "mj-raw", [], [{:text, "<!--[if mso]><table><![endif]-->", _}], _, _}] = parse!(source)
    end

    test "reports unclosed and interleaved EEx blocks as syntax errors" do
      assert {:error, 1, 1, "end of template reached without `<% end %>` for `<%= if x do %>`"} =
               Parser.parse("<%= if x do %>")

      assert {:error, 1, 20, "unmatched closing tag </div> inside `<%= if x do %>`" <> _} =
               Parser.parse("<div><%= if x do %></div><% end %>")

      assert {:error, 1, 27, "unmatched closing tag </div>" <> _} = Parser.parse("<%= if x do %>a<% else %>b</div>")
    end

    test "gives every node a location" do
      assert [
               {:block, :tag, "mj-text", _,
                [{:text, "\n  Hi ", %{line: 1, column: 10}}, {:eex_comment, " note ", %{line: 2, column: 6}}], _, _}
             ] = parse!("<mj-text>\n  Hi <%!-- note --%></mj-text>")
    end

    test "reports invalid UTF-8 at the first invalid byte" do
      for interpolation <- [true, false] do
        assert {:error, 2, 4, "invalid UTF-8 in template" <> _} =
                 Parser.parse(<<"<a>\nbc ", 0xFF, "</a>">>, interpolation: interpolation)
      end
    end

    test "accepts whitespace before the > of close tags" do
      assert [{:block, :tag, "mj-text", _, _, _, _}, {:block, :tag, "mj-style", _, [{:text, ".a {}", _}], _, _}] =
               parse!("<mj-text>a</mj-text ><mj-style>.a {}</mj-style\t>")
    end

    test "only mjml-raw-text=\"false\" leaves mj-raw parsed as HTML" do
      assert [{:block, :tag, "mj-raw", _, [{:block, :tag, "div", _, _, _, _}], _, _}] =
               parse!(~s(<mj-raw mjml-raw-text="false"><div></div></mj-raw>))
    end

    test "reports errors with a location" do
      error = assert_raise ParseError, fn -> parse!("<mjml>\n  <mj-body>\n</mjml>", file: "welcome.mjml") end
      assert {error.file, error.line, error.column} == {"welcome.mjml", 3, 1}
      assert error.description =~ "unmatched closing tag. Expected </mj-body> for <mj-body> at line 2, got: </mjml>"
    end
  end

  describe "plain mode" do
    test "treats braces as text" do
      assert [{:block, :tag, "mj-text", _, [{:text, "{@name}", _}], _, _}] =
               parse!("<mj-text>{@name}</mj-text>", interpolation: false)
    end

    test "treats EEx tags as text" do
      assert [{:block, :tag, "mj-style", _, [{:text, "<%= @x %>", _}], _, _}] =
               parse!("<mj-style><%= @x %></mj-style>", interpolation: false)
    end

    test "treats every tag as an element" do
      assert [
               {:block, :tag, "Table", _, [{:block, :tag, "P", _, _, _, _}], _, _},
               {:self_close, :tag, ".foo", _, _},
               {:block, :tag, ":x", _, _, _, _}
             ] = parse!("<Table><P>x</P></Table><.foo/><:x>y</:x>", interpolation: false)
    end

    test "rejects expression attribute values" do
      assert_raise ParseError, ~r/Expected a value between quotes/, fn ->
        parse!(~s(<mj-text color={@color}>Hi</mj-text>), interpolation: false)
      end
    end
  end

  describe "serializer" do
    test "round trips plain MJML and removes the mjml_eex attributes" do
      source =
        ~s(<mj-raw mjml-raw-text><div></mj-raw><mj-image src='a.png' alt /><mj-text mjml-no-curly-interpolation>a<br>{b}</mj-text>)

      nodes = parse!(source, interpolation: false)

      assert IO.iodata_to_binary(Serializer.to_iodata(nodes)) ==
               ~s(<mj-raw><div></mj-raw><mj-image src='a.png' alt /><mj-text>a<br>{b}</mj-text>)
    end

    test "removing mjml-raw-text gives the same mjml_nif HTML as never having it" do
      with_attribute =
        ~s(<mjml><mj-body><mj-raw mjml-raw-text><div class="a"></mj-raw><mj-raw mjml-raw-text></div></mj-raw></mj-body></mjml>)

      without_attribute = String.replace(with_attribute, " mjml-raw-text", "")
      serialized = with_attribute |> parse!(interpolation: false) |> Serializer.to_iodata() |> IO.iodata_to_binary()

      assert serialized == without_attribute
      assert Mjml.to_html(serialized) == Mjml.to_html(without_attribute)
    end

    test "refuses to serialize expressions" do
      assert_raise ArgumentError, ~r/only plain MJML/, fn -> Serializer.to_iodata(parse!("<mj-text>{@x}</mj-text>")) end
    end
  end

  describe "robustness" do
    @fragments ~w(< > </ /> = " ' { } \\{ <% %> <%= <!-- --> mjml mj-text mj-raw mj-style div br :if :for . Mod.fun a é
                  mjml-raw-text mjml-no-curly-interpolation <!doctype <:s> </:s> <.c> </.c> <mj-text> </mj-text> <div>
                  </div> </mj-raw> <mj-style>) ++
                 [
                   "\n",
                   "\r\n",
                   " ",
                   "\t",
                   "<%= if x do %>",
                   "<% else %>",
                   "<% end %>",
                   "<%= for x <- y do %>",
                   "<%!-- c --%>",
                   "<mj-raw mjml-raw-text>",
                   "</mj-style >"
                 ]

    defp garbage do
      gen all(
            parts <-
              list_of(
                frequency([
                  {8, member_of(@fragments)},
                  {3, string(:printable, max_length: 3)},
                  {1, binary(max_length: 2)}
                ]),
                max_length: 40
              )
          ) do
        Enum.join(parts)
      end
    end

    property "plain mode either parses or returns a ParseError with a location" do
      check all(source <- garbage(), max_runs: 1_000) do
        case MjmlEEx.parse(source) do
          {:ok, nodes} -> assert is_list(nodes)
          {:error, %ParseError{line: line, column: column}} -> assert is_integer(line) and is_integer(column)
        end
      end
    end

    property "template mode either parses or returns an error with a location" do
      check all(source <- garbage(), max_runs: 1_000) do
        capture_io(:stderr, fn ->
          case Parser.parse(source, interpolation: true) do
            {:ok, nodes} -> assert is_list(nodes)
            {:error, line, column, message} -> assert is_integer(line) and is_integer(column) and is_binary(message)
          end
        end)
      end
    end

    property "valid MJML built from the corpus elements round trips through the serializer" do
      check all(
              text <- string(:alphanumeric, max_length: 10),
              color <- member_of(["red", "#fff", "rgb(1,2,3)"]),
              max_runs: 200
            ) do
        source =
          ~s(<mjml><mj-body><mj-section><mj-column><mj-text color="#{color}">#{text}<br></mj-text></mj-column></mj-section></mj-body></mjml>)

        assert source |> parse!(interpolation: false) |> Serializer.to_iodata() |> IO.iodata_to_binary() == source
      end
    end
  end
end
