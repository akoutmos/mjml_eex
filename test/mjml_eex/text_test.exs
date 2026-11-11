defmodule MjmlEEx.TextTest do
  use ExUnit.Case, async: true

  defp to_text(body),
    do: MjmlEEx.to_text("<mjml><mj-body><mj-section><mj-column>#{body}</mj-column></mj-section></mj-body></mjml>")

  defp text(html), do: to_text("<mj-text>#{html}</mj-text>")

  test "leaves out mj-head, and returns an empty string for an email without text" do
    mjml = """
    <mjml>
      <mj-head><mj-title>Title</mj-title><mj-preview>Preview</mj-preview><mj-style>a { color: red; }</mj-style></mj-head>
      <mj-body><mj-section><mj-column><mj-image src="https://example.com/a.png" alt="A" /><mj-spacer /></mj-column></mj-section></mj-body>
    </mjml>
    """

    assert MjmlEEx.to_text(mjml) == ""
  end

  test "separates paragraphs with a blank line, and collapses whitespace" do
    assert to_text(
             "<mj-text>\n  <h1>Hello,\n   Jane!</h1>\n  <p>One   two</p>\n  three <b>four</b></mj-text><mj-text>Five</mj-text>"
           ) ==
             "Hello, Jane!\n\nOne two\n\nthree four\n\nFive\n"
  end

  test "keeps line breaks" do
    assert text("Welcome aboard,<br>Maya<br/><br />CEO") == "Welcome aboard,\nMaya\n\nCEO\n"
  end

  test "writes links with their URL, unless the text is the URL" do
    assert text(~s(Read <a href="https://example.com/docs">the docs</a>.)) ==
             "Read the docs (https://example.com/docs).\n"

    assert text(~s(<a href="https://example.com">https://example.com</a>)) == "https://example.com\n"
    assert text(~s(<a href="mailto:help@example.com">help@example.com</a>)) == "help@example.com\n"
    assert text(~s(<a href="#top">Top</a> <a>Plain</a>)) == "Top Plain\n"
    assert text(~s(<a href="https://example.com"><img src="logo.png" alt="Acme"></a>)) == "Acme (https://example.com)\n"
    assert text(~s(<a href="https://example.com"></a>)) == "https://example.com\n"
  end

  test "writes buttons, linked images, social and navbar links with their URL" do
    assert to_text(~s(<mj-button href="https://example.com/start">Get <b>started</b></mj-button>)) ==
             "Get started: https://example.com/start\n"

    assert to_text(~s(<mj-button>No link</mj-button>)) == "No link\n"
    assert to_text(~s(<mj-image src="a.png" alt="Acme" href="https://example.com" />)) == "Acme: https://example.com\n"
    assert to_text(~s(<mj-image src="a.png" href="https://example.com" />)) == "https://example.com\n"

    assert to_text("""
           <mj-social>
             <mj-social-element name="x-noshare" alt="x" href="https://x.com/acme" />
             <mj-social-element name="github" href="https://github.com/acme" />
             <mj-social-element name="mastodon" href="https://mastodon.social/@acme">Mastodon</mj-social-element>
           </mj-social>
           <mj-navbar><mj-navbar-link href="https://example.com/docs">Docs</mj-navbar-link></mj-navbar>
           """) ==
             "X: https://x.com/acme\nGitHub: https://github.com/acme\nMastodon: https://mastodon.social/@acme\n\nDocs: https://example.com/docs\n"
  end

  test "writes lists, quotes, preformatted text and dividers" do
    assert text(
             "<ul><li>One</li><li>Two<ul><li>Nested</li></ul></li></ul><ol><li>First</li><li><p>Second</p><p>More</p></li></ol>"
           ) ==
             "- One\n- Two\n  - Nested\n\n1. First\n2. Second\n   More\n"

    assert text("<blockquote><p>Quoted</p><p>Twice</p></blockquote>") == "> Quoted\n>\n> Twice\n"
    assert text("<pre>  def x,\n    do: 1</pre>") == "  def x,\n    do: 1\n"
    assert to_text("<mj-text>A<hr>B</mj-text><mj-divider />") == "A\n\n---\n\nB\n\n---\n"
  end

  test "lines up the columns of tables, and leaves out empty columns and rows" do
    assert to_text("""
           <mj-table>
             <tr><th>Item</th><td></td><th>Price</th></tr>
             <tr><td>Mug</td><td></td><td>$19</td></tr>
             <tr><td></td><td></td><td></td></tr>
             <tr><td>Large vase</td><td></td><td>$68</td></tr>
           </mj-table>
           """) == "Item        Price\nMug         $19\nLarge vase  $68\n"

    assert text(
             "<table><tbody><tr><td>Billed to</td><td>Jane<br>Globex</td></tr><tr><td>Due</td><td>Oct 31</td></tr></tbody></table>"
           ) ==
             "Billed to  Jane\n           Globex\n\nDue        Oct 31\n"
  end

  test "leaves out comments, scripts, styles and hidden elements" do
    assert text(~s(<!-- note -->A<!--[if mso]><b>Outlook</b><![endif]--><!--[if !mso]><!-->B<!--<![endif]-->)) == "AB\n"

    assert text(~s[<style>p { color: red; }</style><script>x();</script>Shown<span style="display: none">Hidden</span>]) ==
             "Shown\n"

    assert text(~s(<div style="DISPLAY:none">Hidden</div><p>Shown</p>)) == "Shown\n"
  end

  test "decodes all of HTML's named entities, and leaves out control characters" do
    assert text("Caf&eacute; &uuml;ber &ntilde; &hearts; &iexcl;Hola! &NotEqualTilde; &frac12;") ==
             "Café über ñ ♥ ¡Hola! ≂̸ ½\n"

    assert text("a&#0;b&#7;c&#x80;d&#9;e") == "abcd e\n"
  end

  test "decodes entities" do
    assert text("Tom &amp; Jerry&nbsp;&middot; &#8364;5 &#x2713; &lt;b&gt; &copy;&zwnj;&#847; &unknown;") ==
             "Tom & Jerry · €5 ✓ <b> © &unknown;\n"
  end

  test "keeps the text of HTML that MJML accepts but isn't well-formed" do
    # A wrapper opened in one mj-raw and closed in another (with mjml-raw-text in templates)
    assert MjmlEEx.to_text("""
           <mjml><mj-body>
             <mj-raw><div class="wrapper"></mj-raw>
             <mj-section><mj-column><mj-text>Inside</mj-text></mj-column></mj-section>
             <mj-raw></div></mj-raw>
           </mj-body></mjml>
           """) == "Inside\n"

    # Unclosed tags, as in HTML from a CMS inserted with raw/1
    assert text("<p>One<p>Two &amp; <b>three</b><style>p { color: red; }</style><!-- x -->") == "One Two & three\n"
    assert to_text(~s(<mj-button href="/go"><b>Go</mj-button>)) == "Go: /go\n"
  end

  test "includes accordions and mj-raw" do
    assert to_text("""
           <mj-accordion><mj-accordion-element>
             <mj-accordion-title>Question</mj-accordion-title>
             <mj-accordion-text><p>Answer</p></mj-accordion-text>
           </mj-accordion-element></mj-accordion>
           <mj-raw><p>Raw</p></mj-raw>
           """) == "Question\n\nAnswer\n\nRaw\n"
  end

  test "the generated to_text/1 works with the mjml-raw-text wrapper pattern" do
    [{module, _binary}] =
      Code.compile_string(~S'''
      defmodule MjmlEEx.TextTest.Wrapper do
        use MjmlEEx

        def render(assigns) do
          ~MJML"""
          <mjml><mj-body>
            <mj-raw mjml-raw-text><div class="wrapper"></mj-raw>
            <mj-section><mj-column><mj-text>Hi {@name}</mj-text></mj-column></mj-section>
            <mj-raw mjml-raw-text></div></mj-raw>
          </mj-body></mjml>
          """
        end
      end
      ''')

    assert module.to_text(name: "Jane") == "Hi Jane\n"
  end

  test "converts rendered templates" do
    assigns = %{name: "Jane"}
    import MjmlEEx, only: [sigil_MJML: 2]
    assert MjmlEEx.to_text(~MJML"<mj-text>Hi {@name}</mj-text>") == "Hi Jane\n"
  end
end
