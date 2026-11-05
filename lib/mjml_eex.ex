defmodule MjmlEEx do
  @moduledoc """
  Build MJML emails with HEEx-style templates.

  A template module does `use MjmlEEx` and either defines `render/1` with the `~MJML` sigil:

  ```elixir
  defmodule MyApp.Emails.Welcome do
    use MjmlEEx

    def render(assigns) do
      ~MJML\"\"\"
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text font-size="20px">Hello {@first_name}!</mj-text>
              <mj-button :if={@cta_url} href={@cta_url}>Get started</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
      \"\"\"
    end
  end
  ```

  or leaves `render/1` out and puts the template in a `.meex` file next to the module,
  with the same base name (`welcome.ex` and `welcome.meex`), like LiveView's colocated
  templates.

  `render/1` returns the rendered MJML as an `MjmlEEx.Rendered` struct. To get the email
  HTML, call the generated `to_html/1`:

  ```elixir
  MyApp.Emails.Welcome.to_html(first_name: "Alex", cta_url: "https://example.com")
  ```

  ## Template syntax

  Templates use the same syntax as HEEx:

  - `{@name}` and `{expression}` interpolate into text, and `attr={expression}` into
    attribute values. Values are HTML-escaped; use `raw/1` to insert trusted markup.
  - `:if={...}` and `:for={...}` work on any tag.
  - EEx tags (`<%= ... %>`, `<% ... %>`) and blocks (`if`, `case`, `cond`, `for`) work too.
  - In attributes, `nil` and `false` leave the attribute out. On MJML tags, `true` renders
    as `attr="true"`, since MJML attributes are strings; on HTML tags it renders the bare
    attribute, like HEEx. Lists are joined with spaces on MJML tags (useful for `mj-class`).
  - `{...}` is not interpolated in `mj-style`, `style` and `script`, so CSS braces need no
    escaping. Add `mjml-no-curly-interpolation` to a tag to turn it off for its content.
  - `mj-raw` content is parsed as HTML, so tags must be balanced. To split a wrapper across
    several `mj-raw` tags, add `mjml-raw-text` to make each one raw text.

  ## Validation

  Templates are checked against the MJML spec when they're compiled: unknown tags and
  attributes, attribute values that don't match their MJML type, components nested where they
  aren't allowed, and so on (see `MjmlEEx.ValidationError` for every rule). A template whose
  root is `<mjml>` is checked as a whole document; other templates, such as a function that
  returns a single `mj-section`, are checked on their own.

  By default every problem is a compile error. To relax that, set a level for every rule or
  for individual rules, globally or per template:

  ```elixir
  config :mjml_eex, validation: [invalid_value: :warn, unknown_class: :skip]

  use MjmlEEx, validation: :warn
  ```

  The levels are `:error` (fail the build), `:warn` (print a compiler warning) and `:skip`.
  Template settings apply on top of the application config.

  Attribute values that come from expressions (`color={@color}`) can only be checked when the
  template is rendered. Turn that on in dev and test with
  `config :mjml_eex, runtime_validation: :raise` (or `:warn` to log instead).

  ## Options

  - `:validation` - validation levels for this module's templates, as above.

  - `:layout` - a layout to render the template in: a template module (`MyApp.Emails.Layout`),
    or a function component (`{MyApp.Emails.Components, :layout}`). The layout renders the
    template where it has `{@inner_content}`, and gets the same assigns. The template and the
    layout are validated together as one document when the template compiles.

  - `:template` - the template file, relative to the module's file. Defaults to the module's
    file name with the `.meex` extension. Only used when the module doesn't define `render/1`.

  - `:compiler_opts` - options for the MJML compiler, merged on top of the
    `config :mjml_eex, compiler_opts: [...]` application config (see `compiler_opts/1`). They're
    evaluated each time `to_html/1` runs, so runtime values such as
    `include_path: Application.app_dir(:my_app, "priv/emails")` work. See
    `MjmlEEx.Compilers.Rust` for the supported options.
  """

  alias MjmlEEx.{Component, ParseError, Rendered, ValidationError, Validator}
  alias MjmlEEx.TagEngine.{Compiler, Parser}

  @template_extension ".meex"

  defmacro __using__(opts) do
    opts = Keyword.validate!(opts, [:template, :compiler_opts, :validation, :layout])

    {template, explicit?} =
      case Keyword.fetch(opts, :template) do
        {:ok, template} -> {Path.expand(template, Path.dirname(__CALLER__.file)), true}
        :error -> {Path.rootname(__CALLER__.file) <> @template_extension, false}
      end

    compiler_opts = Keyword.get(opts, :compiler_opts, [])
    validation = Keyword.get(opts, :validation)
    layout = opts |> Keyword.get(:layout) |> expand_layout(__CALLER__)

    # Fail early on invalid settings
    _ = Validator.levels(validation)

    quote do
      import MjmlEEx, only: [sigil_MJML: 2]
      import MjmlEEx.Component
      import Phoenix.HTML, only: [raw: 1]

      # attr/slot declarations, for render/1 and any function components in the module
      MjmlEEx.Component.__setup__(__MODULE__, __ENV__.file, false)

      @__mjml_eex_template__ {unquote(template), unquote(explicit?)}
      @__mjml_eex_validation__ unquote(Macro.escape(validation))
      @__mjml_eex_layout__ unquote(Macro.escape(layout))
      @before_compile MjmlEEx

      @doc "Renders the template with the given assigns and compiles it to email HTML."
      @spec to_html(map() | keyword()) :: String.t()
      def to_html(assigns) do
        MjmlEEx.__to_html__(__MODULE__, assigns, unquote(compiler_opts))
      end
    end
  end

  defp expand_layout(nil, _caller), do: nil

  defp expand_layout({:{}, _, _} = layout, caller), do: layout |> Macro.expand(caller) |> expand_layout(caller)

  defp expand_layout({module, fun}, caller) when is_atom(fun) do
    case Macro.expand(module, caller) do
      module when is_atom(module) ->
        {module, fun}

      _ ->
        raise ArgumentError,
              "the :layout option must be a module or {module, function}, got: #{Macro.to_string(module)}"
    end
  end

  defp expand_layout(module, caller) do
    case Macro.expand(module, caller) do
      module when is_atom(module) ->
        {module, :render}

      other ->
        raise ArgumentError, "the :layout option must be a module or {module, function}, got: #{Macro.to_string(other)}"
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    {template, explicit?} = Module.get_attribute(env.module, :__mjml_eex_template__)
    # A bodiless `def render(assigns)` head, which attr and slot declarations can precede,
    # doesn't count: the template is its body
    render_defined? = match?({:v1, :def, _meta, [_ | _]}, Module.get_definition(env.module, {:render, 1}))
    template_exists? = File.regular?(template)
    relative = Path.relative_to_cwd(template)

    cond do
      render_defined? and template_exists? ->
        raise CompileError,
          file: env.file,
          description: "#{inspect(env.module)} defines render/1 and has a template at #{relative}. Use one or the other"

      render_defined? ->
        quote do
          @external_resource unquote(template)
          unquote(introspection(env, env.file))
          unquote(Component.component_definitions(env.module))
          unquote(layout_wrapper(env.module))
        end

      template_exists? ->
        validation = Module.get_attribute(env.module, :__mjml_eex_validation__)
        source = File.read!(template)

        Component.record_source(env.module, :render, %{
          source: source,
          file: template,
          line: 1,
          column: 1,
          indentation: 0
        })

        ast =
          Compiler.compile(source,
            file: template,
            line: 1,
            validation: validation,
            caller: env,
            layout: layout_source(env.module, env)
          )

        # Declarations before a `def render(assigns)` head were registered for it; ones at the
        # end of the module apply to the generated render/1 too
        unless Map.has_key?(Module.get_attribute(env.module, :__mjml_eex_components__), :render) do
          attrs = Module.get_attribute(env.module, :__mjml_eex_pending_attrs__)
          slots = Module.get_attribute(env.module, :__mjml_eex_pending_slots__)
          Component.register(env.module, :render, :def, attrs, slots, env.line)
        end

        spec = env.module |> Module.get_attribute(:__mjml_eex_components__) |> Map.fetch!(:render)

        quote do
          @external_resource unquote(template)
          unquote(introspection(env, template))

          # Errors and warnings in the template's expressions point to the template file
          @file unquote(template)
          unquote(render_docs(env.module, relative))

          def render(var!(assigns)) do
            var!(assigns) = MjmlEEx.Component.__prepare_assigns__(var!(assigns), unquote(Macro.escape(spec)))
            _ = var!(assigns)
            unquote(ast)
          end

          unquote(Component.component_definitions(env.module, except: [:render]))
          unquote(layout_wrapper(env.module))
        end

      true ->
        reason = if explicit?, do: "the template #{relative} does not exist", else: "there is no #{relative}"

        raise CompileError,
          file: env.file,
          description:
            "#{inspect(env.module)} needs a template: define render/1 using the ~MJML sigil, or add a template file (#{reason})"
    end
  end

  # A `def render(assigns)` head carries the module's own docs, if any
  defp render_docs(module, relative) do
    unless Module.defines?(module, {:render, 1}) do
      quote do
        @doc "Renders the template in #{unquote(relative)} with the given assigns."
        @spec render(map() | keyword()) :: MjmlEEx.Rendered.t()
      end
    end
  end

  # The file the template is in (the .meex file, or the module's file for ~MJML in render/1)
  # and the layout's module, for the telemetry metadata
  defp introspection(env, template_file) do
    layout = Module.get_attribute(env.module, :__mjml_eex_layout__)

    quote do
      @doc false
      def __mjml_eex_template__, do: unquote(template_file)

      @doc false
      def __mjml_eex_layout__, do: unquote(layout)
    end
  end

  @doc """
  The `~MJML` sigil for writing MJML templates inline. Like `~H`, it requires a variable
  named `assigns` in scope, and returns an `MjmlEEx.Rendered` struct.
  """
  defmacro sigil_MJML({:<<>>, meta, [source]}, modifiers)
           when is_binary(source) and modifiers in [[], ~c"noformat"] do
    unless Macro.Env.has_var?(__CALLER__, {:assigns, nil}) do
      raise CompileError,
        file: __CALLER__.file,
        line: __CALLER__.line,
        description: "~MJML requires a variable named \"assigns\" to exist and be set to a map"
    end

    # Heredocs (the only sigils with :indentation) start on the next line; single-line
    # sigils start after `~MJML"`
    position =
      case Keyword.fetch(meta, :indentation) do
        {:ok, indentation} -> [line: __CALLER__.line + 1, indentation: indentation]
        :error -> [line: __CALLER__.line, column: Keyword.get(meta, :column, 1) + byte_size(~s(~MJML"))]
      end

    opts = [
      file: __CALLER__.file,
      validation: template_validation(__CALLER__),
      caller: __CALLER__,
      layout: layout_source_for_sigil(__CALLER__)
    ]

    record_sigil_source(__CALLER__, source, position)
    ast = Compiler.compile(source, opts ++ position)

    # Like ~H, don't warn about `assigns` when the template doesn't use any
    quote do
      _ = var!(assigns)
      unquote(ast)
    end
  end

  defmacro sigil_MJML(_source, modifiers) do
    raise ArgumentError, "~MJML only supports the noformat modifier, got: #{modifiers}"
  end

  # Templates record their source, so they can be used as layouts and validated together
  # with the templates that use them
  defp record_sigil_source(%Macro.Env{module: module, function: {fun, 1}} = caller, source, position)
       when is_atom(module) and not is_nil(module) do
    if Module.open?(module) and Module.has_attribute?(module, :__mjml_eex_components__) do
      info = Map.merge(%{source: source, file: caller.file, column: 1, indentation: 0}, Map.new(position))
      Component.record_source(module, fun, info)
    end
  end

  defp record_sigil_source(_caller, _source, _position), do: :ok

  # The layout's template, when compiling the render/1 of a module with a layout
  defp layout_source_for_sigil(%Macro.Env{module: module, function: {:render, 1}} = caller)
       when is_atom(module) and not is_nil(module) do
    if Module.open?(module), do: layout_source(module, caller)
  end

  defp layout_source_for_sigil(_caller), do: nil

  # The sources of the module's layout and the layouts around it, from the innermost out
  defp layout_source(module, caller) do
    case Module.get_attribute(module, :__mjml_eex_layout__) do
      nil -> nil
      {layout, fun} -> layout_chain(module, layout, fun, caller)
    end
  end

  defp layout_chain(module, layout, fun, caller) do
    case Code.ensure_compiled(layout) do
      {:module, ^layout} ->
        :ok

      {:error, reason} ->
        raise CompileError,
          file: caller.file,
          line: caller.line,
          description:
            "the layout #{inspect(layout)} of #{inspect(module)} isn't available (#{reason}). " <>
              "If it's defined in the same file, define it before the templates that use it"
    end

    sources = if function_exported?(layout, :__mjml_eex_sources__, 0), do: layout.__mjml_eex_sources__(), else: %{}

    source =
      case sources do
        %{^fun => source} ->
          if function_exported?(layout, fun, 1) do
            source
          else
            raise CompileError,
              file: caller.file,
              line: caller.line,
              description: "#{inspect(layout)}.#{fun}/1 can't be used as a layout: it's private"
          end

        _ ->
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description: "#{inspect(layout)}.#{fun}/1 can't be used as a layout: it isn't an MJML EEx template"
      end

    # A template module used as a layout can have a layout itself
    outer =
      with :render <- fun,
           true <- function_exported?(layout, :__mjml_eex_layout__, 0),
           {outer_layout, outer_fun} <- layout.__mjml_eex_layout__() do
        layout_chain(layout, outer_layout, outer_fun, caller)
      else
        _ -> []
      end

    [source | outer]
  end

  # With a layout, render/1 renders the template and passes it to the layout as @inner_content
  defp layout_wrapper(module) do
    case Module.get_attribute(module, :__mjml_eex_layout__) do
      nil ->
        nil

      {layout, fun} ->
        # The layout gets the template's assigns with the defaults of its attr declarations
        assigns =
          case Module.get_attribute(module, :__mjml_eex_components__) do
            %{render: spec} -> quote(do: MjmlEEx.Component.__prepare_assigns__(assigns, unquote(Macro.escape(spec))))
            _ -> quote(do: assigns)
          end

        quote do
          defoverridable render: 1

          def render(assigns) do
            assigns = unquote(assigns)
            MjmlEEx.__render_layout__(unquote(layout), unquote(fun), assigns, super(assigns))
          end
        end
    end
  end

  defp layout_module({layout, _fun}), do: layout
  defp layout_module(nil), do: nil

  @doc false
  def __render_layout__(layout, fun, assigns, inner_content) do
    apply(layout, fun, [assigns |> Map.new() |> Map.put(:inner_content, inner_content)])
  end

  # The `validation:` option of the module's `use MjmlEEx`, if any
  defp template_validation(%Macro.Env{module: module}) when is_atom(module) and not is_nil(module) do
    if Module.open?(module), do: Module.get_attribute(module, :__mjml_eex_validation__)
  end

  defp template_validation(_env), do: nil

  @doc """
  Compiles rendered MJML (or an MJML string) to email HTML with the configured compiler.

  `compiler_opts` are merged on top of the application config (see `compiler_opts/1`).
  Raises if the MJML can't be compiled.
  """
  @spec to_html(Rendered.t() | String.t(), keyword()) :: String.t()
  def to_html(mjml, compiler_opts \\ []) do
    compile!(to_mjml(mjml), configured_compiler(), compiler_opts(compiler_opts))
  end

  @doc """
  Returns rendered MJML as a string, before it's compiled to HTML. Useful for debugging
  and for `validate/2`:

      MyApp.Emails.Welcome.render(first_name: "Alex") |> MjmlEEx.to_mjml()
  """
  @spec to_mjml(Rendered.t() | String.t()) :: String.t()
  def to_mjml(%Rendered{} = rendered), do: to_string(rendered)
  def to_mjml(mjml) when is_binary(mjml), do: mjml

  @doc false
  def __to_html__(module, assigns, template_compiler_opts) do
    assigns = Map.new(assigns)
    compiler = configured_compiler()
    compiler_opts = compiler_opts(template_compiler_opts)

    metadata = %{
      compiler: compiler,
      assigns: assigns,
      mjml_template: nil,
      mjml_template_file: module.__mjml_eex_template__(),
      layout_module: layout_module(module.__mjml_eex_layout__()),
      module: module
    }

    :telemetry.span([:mjml_eex, :render], metadata, fn ->
      Component.__check_assigns__(module, assigns)
      mjml = assigns |> module.render() |> to_mjml()
      html = compile!(mjml, compiler, compiler_opts)
      {html, Map.merge(metadata, %{mjml_template: mjml, rendered_html: html})}
    end)
  end

  defp compile!(mjml, compiler, compiler_opts) do
    case MjmlEEx.Compiler.compile(compiler, mjml, compiler_opts) do
      {:ok, html} -> html
      {:error, error} -> raise "Failed to compile MJML template: #{inspect(error)}"
    end
  end

  @doc """
  Parses a plain MJML string into a tree.

  Plain MJML has no Elixir in it: `{` and `<%` are ordinary text. The tree uses the
  same node format as the template engine (`{:block, :tag, name, attrs, children, meta, close_meta}`,
  `{:self_close, :tag, name, attrs, meta}` and `{:text, text, meta}`); it is not a stable API
  yet.

  ## Options

  - `:file` - the file name to use in errors. Defaults to `"nofile"`.

  ## Examples

      iex> {:ok, [{:block, :tag, "mjml", [], _children, _meta, _close}]} =
      ...>   MjmlEEx.parse("<mjml><mj-body></mj-body></mjml>")

      iex> {:error, %MjmlEEx.ParseError{line: 1}} = MjmlEEx.parse("<mjml><mj-body></mjml>")
  """
  @spec parse(mjml :: String.t(), opts :: keyword()) :: {:ok, [tuple()]} | {:error, ParseError.t()}
  def parse(mjml, opts \\ []) when is_binary(mjml) do
    {:ok, parse!(mjml, opts)}
  rescue
    error in ParseError -> {:error, error}
  end

  @doc """
  Same as `parse/2`, but raises `MjmlEEx.ParseError` if the MJML can't be parsed.
  """
  @spec parse!(mjml :: String.t(), opts :: keyword()) :: [tuple()]
  def parse!(mjml, opts \\ []) when is_binary(mjml) do
    file = Keyword.get(opts, :file, "nofile")
    Parser.parse!(mjml, file: file, interpolation: false)
  end

  @doc """
  Validates a plain MJML string against the MJML spec.

  This checks tags, attribute names and values, nesting, and the document structure.
  It's useful for checking the MJML your templates render, for example in your tests:

      assert :ok = MjmlEEx.validate(MjmlEEx.to_mjml(MyEmail.render(assigns)))

  Returns `:ok`, or `{:error, errors}` with a list of `MjmlEEx.ValidationError`s sorted by
  position. Each error has a `:severity` of `:error` or `:warn`, from the validation settings
  (see "Validation" in `MjmlEEx`); rules set to `:skip` aren't reported. See
  `MjmlEEx.ValidationError` for the rules.

  ## Options

  - `:file` - the file name to use in errors.
  - `:parent` - validate a fragment, such as a file that is included with `mj-include`,
    as the children of the given tag (for example `"mj-column"`) instead of as a whole document.
  - `:validation` - rule levels, on top of `config :mjml_eex, validation: ...`. Either `:error`,
    `:warn` or `:skip` for every rule, or a keyword list such as `[invalid_value: :warn]`.

  ## Examples

      iex> MjmlEEx.validate("<mjml><mj-body><mj-section><mj-column><mj-text>Hi</mj-text></mj-column></mj-section></mj-body></mjml>")
      :ok

      iex> {:error, [error]} = MjmlEEx.validate(~s(<mj-text colour="red">Hi</mj-text>), parent: "mj-column")
      iex> {error.rule, error.message, error.hint}
      {:unknown_attribute, "Attribute colour is illegal", ~s(did you mean "color"?)}
  """
  @spec validate(mjml :: String.t(), opts :: keyword()) :: :ok | {:error, [ValidationError.t()]}
  def validate(mjml, opts \\ []) when is_binary(mjml) do
    case parse(mjml, opts) do
      {:ok, nodes} ->
        validator_opts =
          opts |> Keyword.take([:file, :parent]) |> Keyword.put(:levels, Validator.levels(opts[:validation]))

        case Validator.validate(nodes, validator_opts) do
          [] -> :ok
          errors -> {:error, errors}
        end

      {:error, %ParseError{} = error} ->
        {:error,
         [
           %ValidationError{
             rule: :syntax,
             severity: :error,
             message: error.description |> String.split("\n") |> hd(),
             file: Keyword.get(opts, :file),
             line: error.line,
             column: error.column
           }
         ]}
    end
  end

  @doc """
  Get the configured MJML compiler. By default, the `MjmlEEx.Compilers.Rust` compiler
  is used.
  """
  @spec configured_compiler() :: module()
  def configured_compiler do
    Application.get_env(:mjml_eex, :compiler, MjmlEEx.Compilers.Rust)
  end

  @doc """
  Get the compiler options for a template. The options from the `config :mjml_eex, compiler_opts: [...]`
  application config are merged with the given template options, with the template options taking precedence.
  """
  @spec compiler_opts(template_opts :: keyword()) :: keyword()
  def compiler_opts(template_opts \\ []) do
    :mjml_eex
    |> Application.get_env(:compiler_opts, [])
    |> Keyword.merge(template_opts)
  end
end
