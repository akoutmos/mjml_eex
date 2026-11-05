defmodule MjmlEEx.Spec.OverlayTest do
  use ExUnit.Case, async: true

  alias MjmlEEx.Spec.Overlay

  # These tests check the overlay against mjml_nif itself. If one fails after an mjml
  # upgrade, mjml_nif has changed and the overlay needs updating.

  test "mjml_nif fails on mj-html-attributes" do
    assert Map.has_key?(Overlay.unsupported_tags(), "mj-html-attributes")

    mjml = """
    <mjml>
      <mj-head>
        <mj-html-attributes>
          <mj-selector path=".x td"><mj-html-attribute name="data-id">42</mj-html-attribute></mj-selector>
        </mj-html-attributes>
      </mj-head>
      <mj-body></mj-body>
    </mjml>
    """

    assert {:error, _message} = Mjml.to_html(mjml)
  end

  test "mjml_nif does not inline mj-style inline=\"inline\"" do
    assert {"mj-style", "inline", "inline", _reason} = List.keyfind(Overlay.attribute_value_warnings(), "mj-style", 0)

    mjml = """
    <mjml>
      <mj-head><mj-style inline="inline">.x { color: red; }</mj-style></mj-head>
      <mj-body><mj-section><mj-column><mj-text css-class="x">hi</mj-text></mj-column></mj-section></mj-body>
    </mjml>
    """

    assert {:ok, html} = Mjml.to_html(mjml)
    assert html =~ "<style type=\"text/css\">.x { color: red; }</style>"
    refute html =~ ~r/style="[^"]*color: ?red/
  end

  test "has type strings for every typed overlay attribute" do
    assert "enum(css,html,mjml)" in Overlay.type_strings()
    assert "enum(desktop,mobile)" in Overlay.type_strings()
  end
end
