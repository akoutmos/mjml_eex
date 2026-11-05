defmodule MjmlEEx.Spec.GeneratedTest do
  use ExUnit.Case, async: true

  alias MjmlEEx.Spec.{Generated, Overlay}

  test "has every registered MJML component" do
    assert map_size(Generated.components()) == 31
    assert Generated.components()["mj-text"].ending_tag
    assert Generated.components()["mj-raw"].raw_element
    assert Generated.components()["mj-title"].kind == :head
    assert Generated.components()["mj-wrapper"].kind == :body
  end

  test "inherits allowed and default attributes through the class chain" do
    # mj-wrapper extends mj-section in MJML
    wrapper = Generated.components()["mj-wrapper"]
    assert wrapper.allowed_attributes["gap"] == "unit(px)"
    assert wrapper.default_attributes["padding"] == "20px 0"
  end

  test "only has defaults for allowed attributes" do
    for {name, component} <- Generated.components(),
        attribute <- Map.keys(component.default_attributes) do
      assert Map.has_key?(component.allowed_attributes, attribute), "#{name} has a default for #{attribute}"
    end
  end

  test "every tag in the dependency map is a component or a known element" do
    known = Map.keys(Generated.components()) ++ Map.keys(Overlay.elements())

    for {parent, children} <- Generated.dependencies(), child <- List.wrap(children), child != :any do
      assert parent in known, "unknown parent #{parent}"
      assert child in known, "unknown child #{child} of #{parent}"
    end
  end

  test "ending tags cannot have MJML children" do
    for {name, %{ending_tag: true}} <- Generated.components() do
      assert Generated.dependencies()[name] in [nil, []], "#{name} is an ending tag with children"
    end
  end

  test "every component-less tag has an overlay entry" do
    for tag <- Generated.component_less_tags() do
      assert Map.has_key?(Overlay.elements(), tag)
    end
  end
end
