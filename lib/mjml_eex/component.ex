defmodule MjmlEEx.Component do
  @moduledoc """
  Function components for MJML templates, modeled on `Phoenix.Component`.

  ```elixir
  defmodule MyApp.Emails.Components do
    use MjmlEEx.Component

    attr :href, :string, required: true
    attr :rest, :global, for: "mj-button"
    slot :inner_block, required: true

    def cta(assigns) do
      ~MJML\"\"\"
      <mj-button href={@href} {@rest}>{render_slot(@inner_block)}</mj-button>
      \"\"\"
    end
  end
  ```

  Call components from any template, locally (`<.cta>`, for functions in the same module or
  imported) or remotely (`<MyApp.Emails.Components.cta>`):

  ```heex
  <.cta href={@url} background-color="#F45E43">Get started</.cta>
  ```

  ## Attributes

  `attr name, type, opts` declares an attribute of the next function. The types are
  `:string`, `:integer`, `:boolean`, `:atom`, `:list`, `:map`, `:any` and `:global`. Options:

    * `:required` - the attribute must be given.
    * `:default` - the value when the attribute isn't given.
    * `:values` - the values the attribute accepts.
    * `:doc` - documentation.

  A `:global` attribute collects every attribute the caller passes that isn't declared, so
  it can be spread onto a tag with `{@rest}`. With `for: "mj-button"`, it accepts the
  attributes that `mj-button` accepts (plus `mj-class` and `css-class`); without it, only
  `mj-class` and `css-class`. Add more names with `include: ~w(...)`.

  Attribute names are kept as written, so `background-color="red"` is available as
  `assigns[:"background-color"]`.

  ## Slots

  `slot name, opts` declares a slot. `:inner_block` is the content between the component's
  tags; other slots are given with `<:name>...</:name>`. Options are `:required` and `:doc`,
  and a `do` block can declare the slot's own attributes with `attr`. Render a slot with
  `render_slot/2`, and use `:let` at the call site to receive the argument given to it.

  Template modules (`use MjmlEEx`) support `attr` and `slot` too, for `render/1`. Their
  attributes are checked when the email is rendered with `to_html/1`.

  ## Checking calls

  Calls in templates are checked against these declarations when the template compiles:
  unknown and missing attributes and slots (missing ones aren't reported when the call
  spreads `{...}` attributes), and literal values against their types and `:values`.
  Attributes passed through `:global` with `for:` are checked against that MJML tag. When a
  component's module isn't compiled yet, or the component is defined later in the same
  module, its calls are checked once all modules are compiled. The checks follow the
  validation settings, as the `:component_attribute` and `:component_slot` rules (see
  `MjmlEEx`). Calls in templates outside `use MjmlEEx` or `use MjmlEEx.Component` modules
  are only checked when the declarations are already known.
  """

  alias MjmlEEx.Component.Calls
  alias MjmlEEx.Rendered
  alias Phoenix.HTML.Safe

  @types [:string, :integer, :boolean, :atom, :list, :map, :any, :global]
  @attr_opts [:required, :default, :values, :doc, :for, :include]
  @slot_opts [:required, :doc]

  @typedoc false
  @type attr :: %{
          name: atom(),
          type: atom(),
          required: boolean(),
          default: {:ok, term()} | :none,
          values: [term()] | nil,
          doc: String.t() | nil,
          for: String.t() | nil,
          include: [String.t()],
          line: non_neg_integer()
        }

  defmacro __using__(opts) do
    opts = Keyword.validate!(opts, [:validation])
    # Fail early on invalid settings
    _ = MjmlEEx.Validator.levels(opts[:validation])

    quote do
      import MjmlEEx.Component
      import MjmlEEx, only: [sigil_MJML: 2]
      import Phoenix.HTML, only: [raw: 1]

      MjmlEEx.Component.__setup__(__MODULE__, __ENV__.file, true)
      @__mjml_eex_validation__ unquote(Macro.escape(opts[:validation]))
    end
  end

  @doc false
  # Template modules (use MjmlEEx) generate the component definitions from their own
  # before_compile hook, after render/1, so they pass before_compile? = false
  def __setup__(module, file, before_compile?) do
    unless Module.has_attribute?(module, :__mjml_eex_components__) do
      Module.put_attribute(module, :__mjml_eex_components__, %{})
      Module.put_attribute(module, :__mjml_eex_pending_attrs__, [])
      Module.put_attribute(module, :__mjml_eex_pending_slots__, [])
      Module.put_attribute(module, :__mjml_eex_slot_attrs__, nil)
      Module.put_attribute(module, :__mjml_eex_file__, file)
      Module.put_attribute(module, :__mjml_eex_calls__, [])
      Module.put_attribute(module, :__mjml_eex_sources__, %{})
      Module.put_attribute(module, :on_definition, {__MODULE__, :__on_definition__})
      if before_compile?, do: Module.put_attribute(module, :before_compile, __MODULE__)
    end
  end

  ## Declarations

  @doc """
  Declares an attribute of the next function component. See the module documentation.
  """
  defmacro attr(name, type, opts \\ []) do
    quote bind_quoted: [name: name, type: type, opts: opts, line: __CALLER__.line] do
      MjmlEEx.Component.__attr__(__MODULE__, name, type, opts, line)
    end
  end

  @doc """
  Declares a slot of the next function component. See the module documentation.
  """
  defmacro slot(name, opts \\ [], block \\ [])

  defmacro slot(name, [do: block], []), do: slot_ast(name, [], block, __CALLER__)
  defmacro slot(name, opts, do: block), do: slot_ast(name, opts, block, __CALLER__)
  defmacro slot(name, opts, []), do: slot_ast(name, opts, nil, __CALLER__)

  defp slot_ast(name, opts, block, caller) do
    quote do
      MjmlEEx.Component.__slot_start__(__MODULE__, unquote(name), unquote(opts), unquote(caller.line))
      unquote(block)
      MjmlEEx.Component.__slot_end__(__MODULE__)
    end
  end

  @doc false
  def __attr__(module, name, type, opts, line) do
    validate_attr_declaration!(module, name, type, opts, line)

    attr = %{
      name: name,
      type: type,
      required: Keyword.get(opts, :required, false),
      default: if(Keyword.has_key?(opts, :default), do: {:ok, opts[:default]}, else: :none),
      values: Keyword.get(opts, :values),
      doc: Keyword.get(opts, :doc),
      for: Keyword.get(opts, :for),
      include: Keyword.get(opts, :include, []),
      line: line
    }

    case Module.get_attribute(module, :__mjml_eex_slot_attrs__) do
      nil -> push(module, :__mjml_eex_pending_attrs__, attr, :attr, line)
      slot_attrs -> Module.put_attribute(module, :__mjml_eex_slot_attrs__, [attr | slot_attrs])
    end
  end

  defp validate_attr_declaration!(module, name, type, opts, line) do
    problem =
      attr_problem(name, type, opts) || option_problem(name, type, opts) || slot_attr_problem(module, name, type, opts)

    if problem, do: compile_error!(module, line, problem)
  end

  defp attr_problem(name, type, opts) do
    cond do
      not is_atom(name) ->
        "attribute names must be atoms, got: #{inspect(name)}"

      type not in @types ->
        "invalid type #{inspect(type)} for attr #{inspect(name)}. The types are #{inspect(@types)}"

      Keyword.keys(opts) -- @attr_opts != [] ->
        "invalid options #{inspect(Keyword.keys(opts) -- @attr_opts)} for attr #{inspect(name)}"

      true ->
        nil
    end
  end

  defp option_problem(name, type, opts) do
    cond do
      opts[:required] && Keyword.has_key?(opts, :default) ->
        "attr #{inspect(name)} can't be both required and have a default"

      type == :global and (opts[:required] || opts[:values]) ->
        "global attr #{inspect(name)} can't be required or have :values"

      type != :global and (Keyword.has_key?(opts, :for) or Keyword.has_key?(opts, :include)) ->
        "the :for and :include options are only for :global attrs, but #{inspect(name)} is #{inspect(type)}"

      opts[:for] != nil and MjmlEEx.Validator.attribute_names(opts[:for]) == nil ->
        "the :for option of attr #{inspect(name)} must be an MJML tag, such as \"mj-button\", got: #{inspect(opts[:for])}"

      true ->
        default_problem(name, type, opts)
    end
  end

  defp default_problem(name, type, opts) do
    cond do
      not Keyword.has_key?(opts, :default) or type == :global ->
        nil

      not Calls.type_matches?(type, opts[:default]) ->
        "the default of attr #{inspect(name)} must be of type #{inspect(type)}, got: #{inspect(opts[:default])}"

      opts[:values] && opts[:default] not in opts[:values] ->
        "the default of attr #{inspect(name)} must be one of #{inspect(opts[:values])}, got: #{inspect(opts[:default])}"

      true ->
        nil
    end
  end

  # Slot entries are the caller's, so there's nothing to apply defaults to or collect into
  defp slot_attr_problem(module, name, type, opts) do
    cond do
      Module.get_attribute(module, :__mjml_eex_slot_attrs__) == nil -> nil
      type == :global -> "slot attr #{inspect(name)} can't be :global"
      Keyword.has_key?(opts, :default) -> "slot attr #{inspect(name)} can't have a default"
      true -> nil
    end
  end

  @doc false
  def __slot_start__(module, name, opts, line) do
    unless is_atom(name), do: compile_error!(module, line, "slot names must be atoms, got: #{inspect(name)}")

    case Keyword.keys(opts) -- @slot_opts do
      [] -> :ok
      unknown -> compile_error!(module, line, "invalid options #{inspect(unknown)} for slot #{inspect(name)}")
    end

    Module.put_attribute(module, :__mjml_eex_slot_attrs__, [])
    Module.put_attribute(module, :__mjml_eex_current_slot__, %{name: name, opts: opts, line: line})
  end

  @doc false
  def __slot_end__(module) do
    %{name: name, opts: opts, line: line} = Module.get_attribute(module, :__mjml_eex_current_slot__)
    attrs = module |> Module.get_attribute(:__mjml_eex_slot_attrs__) |> Enum.reverse()
    Module.put_attribute(module, :__mjml_eex_slot_attrs__, nil)

    slot = %{
      name: name,
      required: Keyword.get(opts, :required, false),
      doc: Keyword.get(opts, :doc),
      attrs: attrs,
      line: line
    }

    push(module, :__mjml_eex_pending_slots__, slot, :slot, line)
  end

  defp push(module, key, %{name: name} = entry, kind, line) do
    existing = Module.get_attribute(module, key)

    if Enum.any?(existing, &(&1.name == name)) do
      compile_error!(module, line, "a #{kind} named #{inspect(name)} was already declared")
    end

    if kind == :attr and entry.type == :global and Enum.any?(existing, &(&1.type == :global)) do
      compile_error!(module, line, "a component can only have one :global attr, but #{inspect(name)} is another")
    end

    Module.put_attribute(module, key, [entry | existing])
  end

  @doc false
  def __on_definition__(env, kind, name, args, _guards, _body) when kind in [:def, :defp] do
    attrs = Module.get_attribute(env.module, :__mjml_eex_pending_attrs__)
    slots = Module.get_attribute(env.module, :__mjml_eex_pending_slots__)

    cond do
      attrs == [] and slots == [] ->
        :ok

      length(args) != 1 ->
        compile_error!(
          env.module,
          env.line,
          "attrs and slots can only be declared on functions that take assigns, " <>
            "but #{name}/#{length(args)} doesn't"
        )

      true ->
        __register__(env.module, name, kind, attrs, slots, env.line)
    end
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: :ok

  @doc false
  # Registers declared attrs and slots for a function. Also used by MjmlEEx for render/1
  # when it's generated from a template file.
  def __register__(module, name, kind, attrs, slots, line) do
    components = Module.get_attribute(module, :__mjml_eex_components__)

    if Map.has_key?(components, name) do
      compile_error!(module, line, "attrs and slots for #{name}/1 must be declared before its first clause")
    end

    component = %{kind: kind, attrs: Enum.reverse(attrs), slots: Enum.reverse(slots), line: line}
    Module.put_attribute(module, :__mjml_eex_components__, Map.put(components, name, component))
    Module.put_attribute(module, :__mjml_eex_pending_attrs__, [])
    Module.put_attribute(module, :__mjml_eex_pending_slots__, [])
  end

  @doc false
  defmacro __before_compile__(env), do: __component_definitions__(env.module)

  @doc false
  # Wrappers that apply defaults for components defined in the module, and __mjml_eex_components__/0.
  # `except:` names functions that apply their defaults themselves.
  def __component_definitions__(module, opts \\ []) do
    components = Module.get_attribute(module, :__mjml_eex_components__)
    pending = pending_declarations(module)

    if pending != [] do
      compile_error!(module, hd(pending).line, "attrs and slots must be followed by a function definition")
    end

    wrappers =
      for {name, component} <- components,
          Module.defines?(module, {name, 1}),
          name not in Keyword.get(opts, :except, []) do
        wrapper(name, component)
      end

    # Component calls are checked (again) after every module is compiled, and whenever a
    # module they call changes (see MjmlEEx.Component.Calls)
    deferred =
      case Module.get_attribute(module, :__mjml_eex_calls__) do
        [] ->
          []

        calls ->
          [
            quote do
              @after_verify {MjmlEEx.Component.Calls, :__verify__}

              @doc false
              def __mjml_eex_calls__, do: unquote(Macro.escape(Enum.reverse(calls)))
            end
          ]
      end

    quote do
      unquote_splicing(wrappers)

      @doc false
      def __mjml_eex_components__, do: unquote(Macro.escape(components))

      @doc false
      def __mjml_eex_sources__, do: unquote(Macro.escape(Module.get_attribute(module, :__mjml_eex_sources__) || %{}))

      unquote_splicing(deferred)
    end
  end

  @doc false
  # Records the MJML template of a function (its first ~MJML sigil, or a template file), so it
  # can be used as a layout
  def __record_source__(module, fun, info) do
    sources = Module.get_attribute(module, :__mjml_eex_sources__) || %{}
    Module.put_attribute(module, :__mjml_eex_sources__, Map.put_new(sources, fun, info))
  end

  defp pending_declarations(module) do
    Module.get_attribute(module, :__mjml_eex_pending_attrs__) ++
      Module.get_attribute(module, :__mjml_eex_pending_slots__)
  end

  # Applies defaults, slot defaults and :global collection before calling the function
  defp wrapper(name, %{kind: kind, attrs: attrs, slots: slots}) do
    spec = Macro.escape(%{attrs: attrs, slots: slots})

    body =
      quote do
        super(MjmlEEx.Component.__prepare_assigns__(var!(assigns), unquote(spec)))
      end

    case kind do
      :def ->
        quote do
          defoverridable [{unquote(name), 1}]
          def unquote(name)(var!(assigns)), do: unquote(body)
        end

      :defp ->
        quote do
          defoverridable [{unquote(name), 1}]
          defp unquote(name)(var!(assigns)), do: unquote(body)
        end
    end
  end

  @reserved [:__changed__, :__slot__, :inner_block]

  @doc false
  def __prepare_assigns__(assigns, %{attrs: attrs, slots: slots}) do
    assigns = Map.new(assigns)

    assigns =
      Enum.reduce(attrs, assigns, fn
        %{type: :global, name: name, default: default}, assigns ->
          declared = Enum.map(attrs, & &1.name) ++ Enum.map(slots, & &1.name) ++ @reserved
          rest = Map.drop(assigns, declared)

          defaults =
            case default do
              {:ok, map} -> Map.new(map)
              :none -> %{}
            end

          Map.put(assigns, name, Map.merge(defaults, rest))

        %{name: name, default: {:ok, default}}, assigns ->
          Map.put_new(assigns, name, default)

        _attr, assigns ->
          assigns
      end)

    Enum.reduce(slots, assigns, fn %{name: name}, assigns -> Map.put_new(assigns, name, []) end)
  end

  ## Runtime helpers

  @doc """
  Renders a slot entry, or all the entries of a slot, with an optional argument that the
  caller receives with `:let`.

  ```heex
  {render_slot(@inner_block)}
  <mj-column :for={col <- @col}>{render_slot(col, @item)}</mj-column>
  ```
  """
  @spec render_slot(map() | [map()] | nil, term()) :: Rendered.t()
  def render_slot(slot, argument \\ nil)

  def render_slot(nil, _argument), do: %Rendered{mjml: []}

  def render_slot(entries, argument) when is_list(entries) do
    %Rendered{mjml: Enum.map(entries, &(&1 |> render_slot(argument) |> Safe.to_iodata()))}
  end

  def render_slot(%{inner_block: nil}, _argument), do: %Rendered{mjml: []}

  def render_slot(%{inner_block: inner_block}, argument) when is_function(inner_block, 1) do
    case inner_block.(argument) do
      {:safe, iodata} -> %Rendered{mjml: iodata}
      %Rendered{} = rendered -> rendered
    end
  end

  @doc """
  Puts a key in the assigns, which can be a map or a keyword list. Returns a map.
  """
  @spec assign(map() | keyword(), atom(), term()) :: map()
  def assign(assigns, key, value) when is_map(assigns) and is_atom(key), do: Map.put(assigns, key, value)
  def assign(assigns, key, value) when is_list(assigns), do: assigns |> Map.new() |> assign(key, value)

  @doc """
  Puts a key in the assigns, unless it's already there. `fun` computes the value.
  """
  @spec assign_new(map() | keyword(), atom(), (-> term()) | (map() -> term())) :: map()
  def assign_new(assigns, key, fun) when is_map(assigns) and is_atom(key) do
    case assigns do
      %{^key => _} -> assigns
      _ when is_function(fun, 1) -> Map.put(assigns, key, fun.(assigns))
      _ when is_function(fun, 0) -> Map.put(assigns, key, fun.())
    end
  end

  # render/1 can be called with a keyword list
  def assign_new(assigns, key, fun) when is_list(assigns), do: assigns |> Map.new() |> assign_new(key, fun)

  @doc """
  Returns the assigns as a keyword list of attributes for spreading onto a tag, without the
  reserved and slot keys and without the keys in `exclude`.
  """
  @spec assigns_to_attributes(map(), [atom()]) :: keyword()
  def assigns_to_attributes(assigns, exclude \\ []) do
    for {key, value} <- assigns,
        key not in @reserved and key not in exclude,
        not slot_value?(value),
        do: {key, value}
  end

  defp slot_value?([%{__slot__: _} | _]), do: true
  defp slot_value?(_value), do: false

  @doc false
  # Calls a component function from a template
  def __call__(fun, assigns) when is_function(fun, 1) do
    case fun.(assigns) do
      %Rendered{} = rendered ->
        rendered

      {:safe, _iodata} = safe ->
        safe

      other ->
        raise ArgumentError,
              "expected #{inspect(fun)} to return rendered MJML (use the ~MJML sigil), got: #{inspect(other)}"
    end
  end

  @doc false
  def __unmatched_let__!(pattern, value) do
    raise ArgumentError,
          "cannot match the argument given to render_slot/2 against the :let pattern #{pattern}, got: #{inspect(value)}"
  end

  ## Template modules (D9)

  @doc false
  # Checks a template module's assigns against its render/1 declarations. Raises with every
  # problem found.
  def __check_assigns__(module, assigns) do
    case module.__mjml_eex_components__() do
      %{render: %{attrs: attrs, slots: slots}} ->
        problems =
          Enum.flat_map(attrs, &check_attr(&1, assigns)) ++
            for(
              %{name: name, required: true} <- slots,
              assigns[name] in [nil, []],
              do: "missing required slot #{inspect(name)}"
            )

        if problems != [] do
          raise ArgumentError,
                "invalid assigns for #{inspect(module)}.to_html/1:\n\n" <>
                  Enum.map_join(problems, "\n", &("  * " <> &1))
        end

      _ ->
        :ok
    end
  end

  defp check_attr(%{type: :global}, _assigns), do: []

  defp check_attr(%{name: name, required: required} = attr, assigns) do
    case Map.fetch(assigns, name) do
      :error -> if required, do: ["missing required attr #{inspect(name)}"], else: []
      {:ok, value} -> check_value(attr, value)
    end
  end

  defp check_value(%{name: name, type: type, values: values}, value) do
    cond do
      not Calls.type_matches?(type, value) ->
        ["attr #{inspect(name)} must be of type #{inspect(type)}, got: #{inspect(value)}"]

      values != nil and value not in values ->
        ["attr #{inspect(name)} must be one of #{inspect(values)}, got: #{inspect(value)}"]

      true ->
        []
    end
  end

  defp compile_error!(module, line, message) do
    file = if Module.open?(module), do: Module.get_attribute(module, :__mjml_eex_file__)
    raise CompileError, file: file || "nofile", line: line, description: message
  end
end
