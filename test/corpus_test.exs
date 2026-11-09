defmodule CorpusTest do
  use ExUnit.Case, async: true

  alias MjmlEEx.Formatter
  alias MjmlEEx.TagEngine.{Compiler, Parser, Serializer}
  alias MjmlEEx.Test.Corpus

  # The vendored mrml fixtures (see test/fixtures/corpus/README.md) are the regression
  # baseline. Validation of the corpus is tested in MjmlEEx.ValidatorTest.

  @corpus_dir Path.expand("fixtures/corpus", __DIR__)
  @fixtures Path.wildcard(Path.join(@corpus_dir, "{compare,template}/*.mjml"))

  # Every fixture compiled as a template, as render_fixture(index, assigns). Validation is
  # skipped because a few fixtures break the MJML spec on purpose (see the corpus
  # exceptions in MjmlEEx.ValidatorTest, which also checks template-mode validation).
  for {fixture, index} <- Enum.with_index(@fixtures) do
    ast = Compiler.compile(File.read!(fixture), file: fixture, validation: :skip)

    defp render_fixture(unquote(index), var!(assigns)) do
      _ = var!(assigns)
      unquote(ast)
    end
  end

  # The whole pipeline a user's template goes through: every fixture is formatted, then
  # compiled as a template (parsed and validated, with only the fixture's known exceptions
  # turned off), as render_pipeline(index, assigns)
  for {fixture, index} <- Enum.with_index(@fixtures) do
    formatted = fixture |> File.read!() |> Formatter.format(extension: ".meex")
    validation = for {rule, _tag, _attribute} <- Corpus.exceptions(fixture), do: {rule, :skip}
    ast = Compiler.compile(formatted, file: fixture, validation: validation)

    defp render_pipeline(unquote(index), var!(assigns)) do
      _ = var!(assigns)
      unquote(ast)
    end
  end

  test "the whole corpus is vendored" do
    assert length(Path.wildcard(Path.join(@corpus_dir, "compare/*.mjml"))) == 156
    assert length(Path.wildcard(Path.join(@corpus_dir, "template/*.mjml"))) == 2
  end

  for {fixture, index} <- Enum.with_index(@fixtures) do
    @fixture fixture
    @index index

    test "#{Path.relative_to(fixture, @corpus_dir)} compiled as a template renders the same HTML" do
      rendered = render_fixture(@index, %{})
      assert MjmlEEx.to_html(rendered) == @fixture |> File.read!() |> MjmlEEx.to_html()
    end

    test "#{Path.relative_to(fixture, @corpus_dir)} formatted, validated and rendered as a template gives mjml_nif's HTML" do
      {:ok, html} = @fixture |> File.read!() |> Mjml.to_html()
      assert @index |> render_pipeline(%{}) |> MjmlEEx.to_html() == html
    end

    test "mjml_nif compiles #{Path.relative_to(fixture, @corpus_dir)}" do
      assert {:ok, _html} = @fixture |> File.read!() |> Mjml.to_html()
    end

    test "#{Path.relative_to(fixture, @corpus_dir)} parses in plain and template mode" do
      source = File.read!(@fixture)
      assert {:ok, _nodes} = Parser.parse(source, interpolation: false)
      assert {:ok, _nodes} = Parser.parse(source, interpolation: true)
    end

    test "#{Path.relative_to(fixture, @corpus_dir)} round trips to the same mjml_nif HTML" do
      source = File.read!(@fixture)
      round_tripped = source |> MjmlEEx.parse!() |> Serializer.to_iodata() |> IO.iodata_to_binary()

      assert Mjml.to_html(round_tripped) == Mjml.to_html(source)
    end
  end
end
