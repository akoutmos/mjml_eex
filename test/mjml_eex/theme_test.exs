defmodule MjmlEEx.ThemeTest do
  # The configured theme is app config
  use ExUnit.Case, async: false

  alias MjmlEEx.Theme

  doctest MjmlEEx.Theme

  setup do
    on_exit(fn ->
      Application.delete_env(:mjml_eex, :theme)
      Theme.put(nil)
    end)
  end

  describe "new/1" do
    test "starts from the default theme" do
      assert Theme.new() == %Theme{}
      assert %Theme{primary: "#E11D48", surface: "#FFFFFF"} = Theme.new(primary: "#E11D48")
      assert %Theme{radius: "0px"} = Theme.new(%{radius: "0px"})
    end

    test "raises for unknown tokens" do
      assert_raise ArgumentError, ~r/unknown theme token :primry. The tokens are: :background, /, fn ->
        Theme.new(primry: "#E11D48")
      end
    end

    test "checks values against their MJML types" do
      assert_raise ArgumentError,
                   ~s(invalid theme token :primary: has invalid value: reddish for type Color, got: "reddish"),
                   fn -> Theme.new(primary: "reddish") end

      assert_raise ArgumentError, ~r/invalid theme token :font_size: has invalid value: 16 for type Unit/, fn ->
        Theme.new(font_size: "16")
      end

      assert_raise ArgumentError, ~s(invalid theme token :width: must be a string, got: 600), fn ->
        Theme.new(width: 600)
      end

      assert %Theme{primary: "rgb(225, 29, 72)", line_height: "1.5"} =
               Theme.new(primary: "rgb(225, 29, 72)", line_height: "1.5")
    end

    test "rejects font families that would break out of a style" do
      assert %Theme{font_family: "'Segoe UI', \"Helvetica Neue\", serif"} =
               Theme.new(font_family: "'Segoe UI', \"Helvetica Neue\", serif")

      assert_raise ArgumentError, ~r/invalid theme token :font_family: can't contain ;, \{, \}, < or >/, fn ->
        Theme.new(font_family: "Arial; color: red")
      end
    end

    test "heading_font_family can be nil, other tokens can't" do
      assert %Theme{heading_font_family: nil} = Theme.new(heading_font_family: nil)
      assert_raise ArgumentError, ~r/:font_family: must be a string/, fn -> Theme.new(font_family: nil) end
    end
  end

  describe "configured/0 and current/0" do
    test "apply the app config" do
      assert Theme.configured() == %Theme{}

      Application.put_env(:mjml_eex, :theme, primary: "#E11D48")
      assert %Theme{primary: "#E11D48"} = Theme.configured()
      assert %Theme{primary: "#E11D48"} = Theme.current()

      Application.put_env(:mjml_eex, :theme, primary: "#0EA5E9")
      assert %Theme{primary: "#0EA5E9"} = Theme.current()
    end

    test "raise for an invalid config" do
      Application.put_env(:mjml_eex, :theme, primary: "nope")
      assert_raise ArgumentError, ~r/invalid theme token :primary/, fn -> Theme.current() end
    end
  end

  describe "put/1" do
    test "sets the theme for this process, on top of the config" do
      Application.put_env(:mjml_eex, :theme, primary: "#E11D48", radius: "4px")
      assert :ok = Theme.put(primary: "#0EA5E9")
      assert %Theme{primary: "#0EA5E9", radius: "4px"} = Theme.current()

      task = Task.async(fn -> Theme.current().primary end)
      assert Task.await(task) == "#E11D48"

      assert :ok = Theme.put(nil)
      assert %Theme{primary: "#E11D48"} = Theme.current()
    end

    test "takes a whole theme" do
      theme = Theme.new(primary: "#0EA5E9")
      Theme.put(theme)
      assert Theme.current() == theme
    end

    test "raises for invalid tokens, keeping the current theme" do
      assert_raise ArgumentError, fn -> Theme.put(primary: "nope") end
      assert Theme.current() == %Theme{}
    end
  end
end
