defmodule MjmlEEx.Compilers.Rust do
  @moduledoc """
  This module implements the `MjmlEEx.Compiler` behaviour
  and allows you to compile your MJML templates using the Rust
  NIF (https://hexdocs.pm/mjml/readme.html).

  This is the default compiler.

  ## Options

  The following compiler options are passed through to `Mjml.to_html/2`:

  - `:keep_comments` - When `false`, comments are removed from the rendered HTML. Defaults to `true`.

  - `:social_icon_path` - The base URL used to generate the `mj-social` icon URLs.

  - `:fonts` - A map (or keyword list) of font names to the URLs of their hosted CSS files. Font names must
    be atoms, such as `:"Noto Color Emoji"`.

  - `:include_path` - The directory that `mj-include` paths are resolved from. Relative paths are expanded
    from the current working directory, and symlinks are resolved. It's only for MJML strings passed to
    `MjmlEEx.to_html/2`: templates expand their `mj-include` tags when they compile.

  - `:include_loader` - An `Mjml.ParserOptions.LocalIncludeLoader` struct. Use this instead of
    `:include_path` if you need to build the loader yourself.

  Any other options are ignored.
  """

  @behaviour MjmlEEx.Compiler

  alias Mjml.ParserOptions.LocalIncludeLoader

  @impl true
  def compile(mjml_template) do
    compile(mjml_template, MjmlEEx.compiler_opts())
  end

  @impl true
  def compile(mjml_template, opts) do
    Mjml.to_html(mjml_template, mjml_opts(opts))
  end

  @doc """
  Convert MJML EEx compiler options into the options that `Mjml.to_html/2` expects.
  """
  @spec mjml_opts(opts :: keyword()) :: keyword()
  def mjml_opts(opts) do
    opts
    |> Keyword.take([:keep_comments, :social_icon_path])
    |> maybe_put(:fonts, normalize_fonts(Keyword.get(opts, :fonts)))
    |> maybe_put(:include_loader, include_loader(opts))
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  # The NIF panics if a font name is not an atom
  defp normalize_fonts(nil), do: nil

  defp normalize_fonts(fonts) when is_map(fonts) or is_list(fonts) do
    Map.new(fonts, fn
      {name, url} when is_atom(name) ->
        {name, to_string(url)}

      {name, _url} ->
        raise ArgumentError,
              ~s(font names in the :fonts compiler option must be atoms, such as :"Noto Color Emoji", got: #{inspect(name)})
    end)
  end

  defp normalize_fonts(fonts) do
    raise ArgumentError, "the :fonts compiler option must be a map or keyword list, got: #{inspect(fonts)}"
  end

  defp include_loader(opts) do
    case {Keyword.get(opts, :include_loader), Keyword.get(opts, :include_path)} do
      {nil, nil} ->
        nil

      {loader, nil} ->
        loader

      {nil, path} ->
        %LocalIncludeLoader{path: real_path(path)}

      {_loader, _path} ->
        raise ArgumentError, "only one of the :include_loader and :include_path compiler options may be given"
    end
  end

  # mrml doesn't load includes from a symlinked directory, such as an app's priv directory in
  # dev and test, where Mix links it into _build
  defp real_path(path, depth \\ 0) do
    [root | parts] = path |> Path.expand() |> Path.split()

    Enum.reduce(parts, root, fn part, resolved ->
      candidate = Path.join(resolved, part)

      case File.read_link(candidate) do
        {:ok, target} when depth < 32 -> real_path(Path.expand(target, resolved), depth + 1)
        _not_a_link -> candidate
      end
    end)
  end
end
