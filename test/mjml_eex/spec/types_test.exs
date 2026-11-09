defmodule MjmlEEx.Spec.TypesTest do
  use ExUnit.Case, async: true

  alias MjmlEEx.Spec.{Generated, Overlay, Types}

  doctest Types

  @vectors "../../fixtures/spec/type_vectors.json"
           |> Path.expand(__DIR__)
           |> File.read!()
           |> JSON.decode!()

  test "the type vectors were generated from the same MJML version as the spec" do
    assert @vectors["mjml_version"] == Generated.mjml_version()
  end

  test "there are type vectors for every type string in the spec" do
    assert Enum.sort(Map.keys(@vectors["types"])) == Generated.type_strings()
  end

  for {type_string, vectors} <- @vectors["types"] do
    test "agrees with MJML on every vector for #{type_string}" do
      mismatches =
        for %{"value" => value, "valid" => valid} = vector <- unquote(Macro.escape(vectors)),
            {Types.valid?(unquote(type_string), value), Types.error_message(unquote(type_string), value)} !=
              {valid, vector["message"]} do
          %{
            value: value,
            mjml: {valid, vector["message"]},
            mjml_eex: {Types.valid?(unquote(type_string), value), Types.error_message(unquote(type_string), value)}
          }
        end

      assert mismatches == []
    end
  end

  test "every overlay type string is a valid MJML type" do
    for type_string <- Overlay.type_strings() do
      assert is_boolean(Types.valid?(type_string, "x"))
    end
  end

  test "builds checkers for type strings that are not in the spec" do
    assert Types.valid?("unit(em){2}", "1em 2em")
    refute Types.valid?("unit(em){2}", "1em")

    assert Types.error_message("unit(em){2}", "1em") ==
             "has invalid value: 1em for type Unit, only accepts (em) units and 2 value(s)"
  end

  test "raises for unknown type strings" do
    assert_raise ArgumentError, "No type found for bogus", fn -> Types.valid?("bogus", "x") end
    assert_raise ArgumentError, "Invalid MJML type enum()", fn -> Types.valid?("enum()", "x") end
  end
end
