# Ported from MJML's mjml-core/src/types/*.js (boolean, color, enum, integer, string,
# type, unit and helpers/colors), MJML v5.4.1 (https://github.com/mjmlio/mjml, commit 1c434fc).
# MJML is MIT licensed: Copyright (c) 2016 Mailjet SAS, https://mjml.io
defmodule MjmlEEx.Spec.Types do
  # Validates attribute values against MJML type strings such as `unit(px,%){1,4}`,
  # `enum(left,right)` or `color`.
  #
  # This is a port of MJML's `mjml-core/src/types/*.js` (MJML 5.4.1,
  # MIT license), including its quirks, so that it gives the same answers as MJML's own
  # validator:
  #
  # - Like `mjml-parser-xml`, the attribute values `"true"` and `"false"` are treated as
  #   booleans. They are the only valid values for the `boolean` type.
  # - The `rgb(...)` and `rgba(...)` color patterns and the `integer` pattern are not
  #   anchored, so `"foo rgb(1,2,3)"` is a valid color and `"a1"` a valid integer.
  # - `string` accepts any value.
  #
  # `test/fixtures/spec/type_vectors.json` holds MJML's own results for every type string,
  # and the test suite checks that this module agrees with all of them.
  #
  # Checkers for the type strings in `MjmlEEx.Spec.Generated` and `MjmlEEx.Spec.Overlay`
  # are built at compile time. Other type strings are built on each call.
  @moduledoc false

  alias MjmlEEx.Spec.{Generated, Overlay}
  alias MjmlEEx.Spec.Types.Checker

  @doc """
  Returns `true` if MJML's validator would accept `value` for the type string.

  Raises `ArgumentError` if the type string doesn't match any MJML type.

  ## Examples

      iex> MjmlEEx.Spec.Types.valid?("unit(px,%){1,4}", "10px 0")
      true

      iex> MjmlEEx.Spec.Types.valid?("enum(left,right)", "center")
      false
  """
  @spec valid?(type_string :: String.t(), value :: String.t()) :: boolean()
  def valid?(type_string, value) when is_binary(type_string) and is_binary(value) do
    type_string
    |> checker()
    |> Checker.check(value)
  end

  @doc """
  Returns MJML's error message for an invalid value, or `nil` if the value is valid.
  The message is the part that follows `Attribute <name> ` in MJML's validator output.

  ## Examples

      iex> MjmlEEx.Spec.Types.error_message("enum(left,right)", "center")
      "has invalid value: center for type Enum, only accepts left, right"

      iex> MjmlEEx.Spec.Types.error_message("enum(left,right)", "left")
      nil
  """
  @spec error_message(type_string :: String.t(), value :: String.t()) :: String.t() | nil
  def error_message(type_string, value) when is_binary(type_string) and is_binary(value) do
    checker = checker(type_string)

    if Checker.check(checker, value) do
      nil
    else
      Checker.error_message(checker, value)
    end
  end

  defp checker(type_string) do
    precompiled(type_string) || Checker.build(type_string)
  end

  # Precompile a checker for every known type string
  for type_string <- Enum.uniq(Generated.type_strings() ++ Overlay.type_strings()) do
    defp precompiled(unquote(type_string)), do: unquote(Macro.escape(Checker.build(type_string)))
  end

  defp precompiled(_type_string), do: nil
end
