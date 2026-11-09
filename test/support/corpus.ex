defmodule MjmlEEx.Test.Corpus do
  @moduledoc false

  # The mrml fixtures vendored in test/fixtures/corpus (see its README.md)

  @dir Path.expand("../fixtures/corpus", __DIR__)

  def dir, do: @dir

  def fixtures, do: Path.wildcard(Path.join(@dir, "{compare,template}/*.mjml"))

  # Corpus fixtures that are expected to have problems, as {rule, tag, attribute}: mrml uses
  # some of its fixtures to test attributes it accepts beyond MJML's spec
  def exceptions do
    %{
      "compare/mj-body-width.mjml" => [{:invalid_value, "mj-body", "width"}],
      "compare/mj-column-mobile-width-pixel.mjml" => [{:unknown_attribute, "mj-column", "mobile-width"}],
      "compare/mj-hero-width.mjml" => [{:unknown_attribute, "mj-hero", "width"}],
      "compare/mj-spacer.mjml" => [
        {:unknown_attribute, "mj-spacer", "vertical-align"},
        {:unknown_attribute, "mj-spacer", "width"}
      ],
      # MJML treats ending tag content as raw HTML, so it doesn't notice the nested
      # component; mrml renders it as a literal <mj-divider> tag
      "compare/mj-divider-in-mj-text.mjml" => [{:ending_tag, "mj-divider", nil}]
    }
  end

  def exceptions(fixture), do: Map.get(exceptions(), Path.relative_to(fixture, @dir), [])
end
