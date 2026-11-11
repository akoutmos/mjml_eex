defmodule MjmlEEx.Theme do
  @moduledoc """
  The colors, fonts and sizes that `MjmlEEx.CoreComponents` are styled with.

  The default theme is a neutral gray palette with an indigo accent. Change any of it for the
  whole app in your config:

  ```elixir
  config :mjml_eex, :theme,
    primary: "#E11D48",
    font_family: "Inter, Helvetica, Arial, sans-serif"
  ```

  To use another theme for some emails, such as one per customer in a multi-brand app, put it
  in the process that renders them, before rendering:

  ```elixir
  MjmlEEx.Theme.put(primary: customer.brand_color)
  MyApp.Emails.Welcome.to_html(assigns)
  ```

  Values are MJML attribute values, so sizes need their unit (`"16px"`), and they're checked
  against MJML's types when the theme is built. Colors are hex colors (`"#E11D48"` or
  `"#E14"`), `rgb()` or `rgba()` colors, or color names, which are the colors MJML accepts
  and that Outlook can show. To check values that come from your users, such as a brand color
  from a settings form, use `validate/1` when they're saved.

  ## Tokens

  Colors:

    * `:primary` - buttons, links and accents. Defaults to `"#4F46E5"`.
    * `:primary_text` - text on `:primary`, such as button labels. Defaults to `"#FFFFFF"`.
    * `:background` - the email's background, around the cards. Defaults to `"#F4F4F5"`.
    * `:surface` - cards. Defaults to `"#FFFFFF"`.
    * `:subtle` - quiet fills inside cards: secondary buttons and codes. Defaults to `"#F4F4F5"`.
    * `:text` - body text. Defaults to `"#3F3F46"`.
    * `:heading` - headings and emphasized text. Defaults to `"#18181B"`.
    * `:muted` - secondary text, such as table headers and footers. Defaults to `"#71717A"`.
    * `:border` - dividers and table rules. Defaults to `"#E4E4E7"`.
    * `:info`, `:success`, `:warning` and `:danger` - the titles of callouts, and the danger
      button. Default to `"#1D4ED8"`, `"#15803D"`, `"#B45309"` and `"#B91C1C"`.
    * `:info_background`, `:success_background`, `:warning_background` and
      `:danger_background` - the backgrounds of callouts. Default to `"#EFF6FF"`,
      `"#F0FDF4"`, `"#FFFBEB"` and `"#FEF2F2"`.

  Typography:

    * `:font_family` - defaults to a system font stack.
    * `:heading_font_family` - defaults to `:font_family`.
    * `:monospace_font_family` - for codes. Defaults to a monospace font stack.
    * `:font_size` - body text. Defaults to `"16px"`.
    * `:line_height` - body text. Defaults to `"24px"`.

  Shapes and sizes:

    * `:radius` - the corners of cards. Defaults to `"8px"`.
    * `:button_radius` - the corners of buttons, callouts and codes. Defaults to `"6px"`.
    * `:width` - the width of the email. Defaults to `"600px"`.

  To use a web font, add an `mj-font` for it with the `:head` slot of
  `MjmlEEx.CoreComponents.email/1`, and put it first in `:font_family`.
  """

  alias MjmlEEx.Spec.Types

  @system_fonts "-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif"
  @monospace_fonts "SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, monospace"

  defstruct primary: "#4F46E5",
            primary_text: "#FFFFFF",
            background: "#F4F4F5",
            surface: "#FFFFFF",
            subtle: "#F4F4F5",
            text: "#3F3F46",
            heading: "#18181B",
            muted: "#71717A",
            border: "#E4E4E7",
            info: "#1D4ED8",
            info_background: "#EFF6FF",
            success: "#15803D",
            success_background: "#F0FDF4",
            warning: "#B45309",
            warning_background: "#FFFBEB",
            danger: "#B91C1C",
            danger_background: "#FEF2F2",
            font_family: @system_fonts,
            heading_font_family: nil,
            monospace_font_family: @monospace_fonts,
            font_size: "16px",
            line_height: "24px",
            radius: "8px",
            button_radius: "6px",
            width: "600px"

  @type t :: %__MODULE__{
          primary: String.t(),
          primary_text: String.t(),
          background: String.t(),
          surface: String.t(),
          subtle: String.t(),
          text: String.t(),
          heading: String.t(),
          muted: String.t(),
          border: String.t(),
          info: String.t(),
          info_background: String.t(),
          success: String.t(),
          success_background: String.t(),
          warning: String.t(),
          warning_background: String.t(),
          danger: String.t(),
          danger_background: String.t(),
          font_family: String.t(),
          heading_font_family: String.t() | nil,
          monospace_font_family: String.t(),
          font_size: String.t(),
          line_height: String.t(),
          radius: String.t(),
          button_radius: String.t(),
          width: String.t()
        }

  # The MJML type each token is checked against, the type of the MJML attributes it's used in.
  # The radii are also used in inline styles, so they're checked as sizes, rather than as the
  # `string` type of MJML's border-radius attributes.
  @checks %{
    primary: "color",
    primary_text: "color",
    background: "color",
    surface: "color",
    subtle: "color",
    text: "color",
    heading: "color",
    muted: "color",
    border: "color",
    info: "color",
    info_background: "color",
    success: "color",
    success_background: "color",
    warning: "color",
    warning_background: "color",
    danger: "color",
    danger_background: "color",
    font_family: :font_family,
    heading_font_family: :font_family,
    monospace_font_family: :font_family,
    font_size: "unit(px)",
    line_height: "unit(px,%,)",
    radius: "unit(px,%){1,4}",
    button_radius: "unit(px,%){1,4}",
    width: "unit(px)"
  }

  @token_names Map.new(@checks, fn {key, _type} -> {Atom.to_string(key), key} end)

  # MJML's color type accepts any value that contains an rgb(...) or rgba(...) color, so a
  # color must also have this shape, with nothing before or after it
  @color_shape ~r/\A(?:#[0-9a-f]+|rgba?\([0-9.,\s]*\)|[a-z]+)\z/i

  @key {__MODULE__, :theme}

  @doc """
  Builds a theme from the default theme and the given tokens. Raises `ArgumentError` for
  unknown tokens and invalid values; see `validate/1` for a version that doesn't raise.

  ## Examples

      iex> theme = MjmlEEx.Theme.new(primary: "#E11D48")
      iex> {theme.primary, theme.surface}
      {"#E11D48", "#FFFFFF"}
  """
  @spec new(t() | map() | keyword()) :: t()
  def new(tokens \\ []), do: merge(%__MODULE__{}, tokens)

  @doc """
  Returns `theme` with the given tokens changed. Raises `ArgumentError` for unknown tokens
  and invalid values.
  """
  @spec merge(t(), t() | map() | keyword()) :: t()
  def merge(%__MODULE__{} = theme, tokens) when is_map(tokens) or is_list(tokens) do
    case apply_tokens(theme, tokens) do
      {:ok, theme} -> theme
      {:error, message} -> raise ArgumentError, message
    end
  end

  @doc """
  Builds a theme like `new/1`, but returns `{:error, message}` for unknown tokens and invalid
  values instead of raising.

  Use it to check tokens that come from your users, such as a brand color from a settings
  form, when they're saved, rather than when an email is rendered with them.

  ## Examples

      iex> {:ok, theme} = MjmlEEx.Theme.validate(primary: "#E11D48")
      iex> theme.primary
      "#E11D48"

      iex> {:error, message} = MjmlEEx.Theme.validate(primary: "#E11D48; display: none")
      iex> message
      ~s[invalid theme token :primary: must be a hex color, such as "#E11D48", an rgb() or rgba() ] <>
        ~s[color, or a color name, got: "#E11D48; display: none"]
  """
  @spec validate(t() | map() | keyword()) :: {:ok, t()} | {:error, String.t()}
  def validate(tokens) when is_map(tokens) or is_list(tokens), do: apply_tokens(%__MODULE__{}, tokens)

  defp apply_tokens(_theme, %__MODULE__{} = theme), do: check(theme)

  defp apply_tokens(theme, tokens) do
    tokens
    |> Enum.reduce_while({:ok, theme}, fn
      {key, value}, {:ok, theme} when is_map_key(@checks, key) -> {:cont, {:ok, Map.put(theme, key, value)}}
      {key, _value}, _acc -> {:halt, {:error, unknown_token(key)}}
    end)
    |> case do
      {:ok, theme} -> check(theme)
      error -> error
    end
  end

  defp unknown_token(key) when is_map_key(@token_names, key),
    do: "unknown theme token #{inspect(key)}. Tokens are atoms, such as #{inspect(@token_names[key])}"

  defp unknown_token(key) do
    "unknown theme token #{inspect(key)}. The tokens are: " <>
      Enum.map_join(Enum.sort(Map.keys(@checks)), ", ", &inspect/1)
  end

  # Checks every token, and trims the whitespace around the values
  defp check(theme) do
    Enum.reduce_while(@checks, {:ok, theme}, fn {key, type}, {:ok, theme} ->
      value = theme |> Map.fetch!(key) |> trim()

      case problem(key, value, type) do
        nil -> {:cont, {:ok, Map.put(theme, key, value)}}
        problem -> {:halt, {:error, "invalid theme token #{inspect(key)}: #{problem}, got: #{inspect(value)}"}}
      end
    end)
  end

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value), do: value

  defp problem(:heading_font_family, nil, _type), do: nil
  defp problem(_key, value, _type) when not is_binary(value), do: "must be a string"

  # Font families end up in inline styles, where these would end the declaration
  defp problem(_key, value, :font_family) do
    if String.contains?(value, [";", "{", "}", "<", ">"]), do: "can't contain ;, {, }, < or >"
  end

  defp problem(_key, value, "color") do
    if !Regex.match?(@color_shape, value) or Types.error_message("color", value) do
      ~s[must be a hex color, such as "#E11D48", an rgb() or rgba() color, or a color name]
    end
  end

  defp problem(_key, value, type), do: Types.error_message(type, value)

  @doc """
  The theme of the app: the default theme with the tokens from
  `config :mjml_eex, :theme`.
  """
  @spec configured() :: t()
  def configured do
    tokens = Application.get_env(:mjml_eex, :theme, [])

    # Components ask for the theme every time they render, so it's built once per config
    case :persistent_term.get(@key, nil) do
      {^tokens, theme} ->
        theme

      _other ->
        theme = new(tokens)
        :persistent_term.put(@key, {tokens, theme})
        theme
    end
  end

  @doc """
  The theme the core components use: the one given to `put/1` in this process, or the
  configured one.
  """
  @spec current() :: t()
  def current do
    case Process.get(@key) do
      nil -> configured()
      theme -> theme
    end
  end

  @doc """
  Sets the theme for the emails rendered by this process, like `Gettext.put_locale/1` does
  for the locale. Tokens are applied on top of the configured theme. `nil` goes back to the
  configured theme.

  Emails are rendered in the process that calls `to_html/1`, so put the theme in that process.

  Like `new/1`, it raises `ArgumentError` for invalid tokens. If they come from your users,
  check them with `validate/1` when they're saved.
  """
  @spec put(t() | map() | keyword() | nil) :: :ok
  def put(nil) do
    Process.delete(@key)
    :ok
  end

  def put(theme) do
    Process.put(@key, merge(configured(), theme))
    :ok
  end

  @doc false
  # Calls fun with theme as the current theme, then puts back the one before. Components use it
  # to style their content with another theme, such as hero/1 with light text on a dark color.
  @spec __with__(t(), (-> result)) :: result when result: term()
  def __with__(%__MODULE__{} = theme, fun) do
    previous = Process.get(@key)
    Process.put(@key, theme)

    try do
      fun.()
    after
      if previous, do: Process.put(@key, previous), else: Process.delete(@key)
    end
  end
end
