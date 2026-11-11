defmodule MjmlEEx.Validator do
  @moduledoc false

  # Validates a tree from MjmlEEx.TagEngine.Parser against the MJML spec
  # (MjmlEEx.Spec.Generated and MjmlEEx.Spec.Overlay). See MjmlEEx.ValidationError
  # for the rules. Where MJML's validator (mjml-validator) has the same rule, the
  # message is MJML's.
  #
  # Tag names are compared in lowercase, like MJML's parser (and mrml) do.
  #
  # Expressions are transparent: the children of EEx blocks are validated as children
  # of the enclosing element, `:if`/`:for` attributes are ignored, and attribute values
  # given as `{...}` expressions are not type checked. Function components and slots
  # are not validated yet, but their children are.

  alias MjmlEEx.Spec.{Generated, Overlay, Types}
  alias MjmlEEx.TagEngine.Tags
  alias MjmlEEx.ValidationError

  @components Generated.components()
  @dependencies Generated.dependencies()
  @dependency_order Generated.dependency_order()
  @global_attributes Generated.global_attributes()
  @elements Overlay.elements()
  @unsupported_tags Overlay.unsupported_tags()
  @unsupported_children Overlay.unsupported_children()
  @content_restrictions Overlay.content_restrictions()
  @comment_parents Overlay.comment_parents()
  @mrml "mrml, the MJML compiler used by mjml_nif"

  # Suggestions for common mistakes that aren't close enough for "did you mean"
  @aliases %{
    "class" => "css-class",
    "bgcolor" => "background-color",
    "background-image" => "background-url",
    "mj-hr" => "mj-divider",
    "mj-row" => "mj-section",
    "mj-container" => "mj-wrapper"
  }
  @known_tags Enum.sort(Map.keys(@components) ++ Map.keys(@elements) ++ Map.keys(@unsupported_tags))
  # Tags to suggest for a misspelled one
  @suggested_tags @known_tags -- Map.keys(@unsupported_tags)

  # mj-all and mj-class accept any attribute that some component accepts
  @any_component_attributes @components
                            |> Enum.flat_map(fn {_name, component} -> Map.keys(component.allowed_attributes) end)
                            |> Enum.uniq()
                            |> Enum.sort()

  # Every rule except :syntax (which always fails) can be set to :error, :warn or :skip
  @rules ~w(root unknown_tag unsupported_tag invalid_child ending_tag unexpected_text unknown_attribute
            duplicate_attribute missing_attribute invalid_value unsupported_value unknown_class empty_title
            component_attribute component_slot)a
  @levels [:error, :warn, :skip]

  @doc false
  def rules, do: @rules

  @doc false
  # The end of a build error: how to turn down the rules that its errors broke
  @spec rules_hint([ValidationError.t()]) :: String.t()
  def rules_hint(errors) do
    case errors |> Enum.map(& &1.rule) |> Enum.uniq() |> Enum.filter(&(&1 in @rules)) do
      [] ->
        ""

      rules ->
        levels = Enum.map_join(rules, ", ", &"#{&1}: :warn")

        "\nTo allow them, set their rules to :warn or :skip, for the whole app or for one module:\n\n" <>
          "    config :mjml_eex, validation: [#{levels}]\n" <>
          "    use MjmlEEx, validation: [#{levels}]\n"
    end
  end

  @doc """
  Resolves the level of every rule from the `config :mjml_eex, validation: ...` application
  config and the given override (a template's `validation:` option or `validate/2`'s). Each is
  either a level for every rule, or a keyword list of rules and levels. Rules default to `:error`.

  When `env` is the env of a module being compiled, the config is read with
  `Application.compile_env/4`, so that Mix compiles the module again when the config changes.
  """
  @spec levels(term(), Macro.Env.t() | nil) :: %{atom() => :error | :warn | :skip}
  def levels(override \\ nil, env \\ nil) do
    defaults = Map.new(@rules, &{&1, :error})

    [config(env), override]
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(defaults, &apply_levels/2)
  end

  # compile_env/4 only uses the env to record which module read the config, and it doesn't
  # accept envs from inside functions, such as a ~MJML sigil's
  defp config(%Macro.Env{module: module} = env) when is_atom(module) and not is_nil(module),
    do: Application.compile_env(%{env | function: nil}, :mjml_eex, :validation, nil)

  defp config(_env), do: Application.get_env(:mjml_eex, :validation)

  defp apply_levels(level, levels) when level in @levels, do: Map.new(levels, fn {rule, _} -> {rule, level} end)

  defp apply_levels(rule_levels, levels) when is_list(rule_levels) do
    Enum.reduce(rule_levels, levels, fn
      {rule, level}, levels when rule in @rules and level in @levels ->
        Map.put(levels, rule, level)

      other, _levels ->
        raise ArgumentError,
              "invalid validation setting #{inspect(other)}. Expected {rule, level} with a rule in " <>
                "#{inspect(@rules)} and a level in #{inspect(@levels)}"
    end)
  end

  defp apply_levels(other, _levels) do
    raise ArgumentError,
          "invalid validation setting #{inspect(other)}. Expected one of #{inspect(@levels)} or a keyword list of rules and levels"
  end

  # Options:
  #
  #   * :file - for error locations
  #   * :levels - from levels/1 (default: levels())
  #   * :parent - validate the nodes as the children of this tag
  #   * :fragment - validate the nodes without a parent or document checks (template
  #     fragments, whose context is only known where they're used)
  #
  # Without :parent or :fragment, the nodes are a whole document.
  @doc false
  @spec validate([tuple()], keyword()) :: [ValidationError.t()]
  def validate(nodes, opts \\ []) do
    levels = Keyword.get_lazy(opts, :levels, &levels/0)

    parent = Keyword.get(opts, :parent)

    if parent != nil and parent not in @known_tags do
      raise ArgumentError, "unknown :parent #{inspect(parent)}. Expected an MJML tag, such as \"mj-column\""
    end

    ctx = %{
      file: Keyword.get(opts, :file),
      parent: parent,
      parent_meta: %{line: 1, column: 1},
      # The content of an ending tag is HTML
      in_ending: if(parent && ending_tag?(parent), do: parent),
      html_allowed: false,
      levels: levels
    }

    errors =
      cond do
        # Where a fragment is used is only known at the call, so it can be HTML for an ending tag
        Keyword.get(opts, :fragment, false) -> validate_children(nodes, %{ctx | html_allowed: true}, [])
        ctx.parent == nil -> nodes |> validate_document(ctx) |> check_class_references(nodes, ctx)
        true -> validate_children(nodes, ctx, [])
      end

    errors
    |> Enum.reject(&(&1.severity == :skip))
    |> Enum.sort_by(&{&1.line, &1.column})
  end

  ## Document root

  defp validate_document(nodes, ctx) do
    nodes = flatten(nodes)
    {elements, others} = Enum.split_with(nodes, &element?/1)

    errors =
      others
      |> Enum.filter(&stray_text?/1)
      |> Enum.map(fn {:text, text, meta} ->
        error(:unexpected_text, ctx, text_location(text, meta),
          message: "Text is not allowed outside the <mjml> root element"
        )
      end)

    case elements do
      [] ->
        [
          error(:root, ctx, %{line: 1, column: 1}, message: "A document must have a single <mjml> root element")
          | errors
        ]

      [root | extra] ->
        root_errors =
          if element_name(root) == "mjml" do
            validate_element(root, %{ctx | parent: :root}, [])
          else
            [
              error(:root, ctx, element_meta(root),
                tag: element_name(root),
                message: "A document must have a single <mjml> root element, got: <#{element_name(root)}>"
              )
              | validate_element(root, %{ctx | parent: :root}, [])
            ]
          end

        extra_errors =
          Enum.flat_map(extra, fn node ->
            [
              error(:root, ctx, element_meta(node),
                tag: element_name(node),
                message: "A document must have a single <mjml> root element, got another: <#{element_name(node)}>"
              )
              | validate_element(node, %{ctx | parent: :root}, [])
            ]
          end)

        root_errors ++ extra_errors ++ errors
    end
  end

  ## Children

  defp validate_children(nodes, ctx, acc) do
    nodes
    |> flatten()
    |> Enum.reduce(acc, fn node, acc -> validate_node(node, ctx, acc) end)
  end

  # EEx blocks are transparent: their clauses' children belong to the enclosing element
  defp flatten(nodes) do
    Enum.flat_map(nodes, fn
      {:eex_block, _expr, clauses, _meta} ->
        Enum.flat_map(clauses, fn {children, _expr, _meta} -> flatten(children) end)

      node ->
        [node]
    end)
  end

  defp validate_node({:block, :tag, _, _, _, _, _} = node, ctx, acc), do: validate_element(node, ctx, acc)
  defp validate_node({:self_close, :tag, _, _, _} = node, ctx, acc), do: validate_element(node, ctx, acc)

  # The content of components and slots is checked, but where it ends up is only known inside
  # the component (for example in an mj-text), so HTML is allowed there and the MJML tags in
  # it aren't checked against an outer parent
  defp validate_node({:block, _type, _name, _attrs, children, _meta, _close}, ctx, acc) do
    validate_children(children, %{ctx | parent: nil, html_allowed: true}, acc)
  end

  defp validate_node({:text, text, meta} = node, ctx, acc) do
    acc = check_comments(text, meta, ctx, acc)

    if ctx.in_ending == nil and stray_text?(node) and text_parent?(ctx.parent) do
      [
        error(:unexpected_text, ctx, text_location(text, meta, ctx.parent_meta),
          tag: ctx.parent,
          message: "Text is not allowed directly inside #{ctx.parent}"
        )
        | acc
      ]
    else
      acc
    end
  end

  defp validate_node(_node, _ctx, acc), do: acc

  # Text in containers is dropped by MJML and output as-is by mrml
  defp text_parent?(parent) when is_binary(parent) do
    case @components do
      %{^parent => %{ending_tag: false}} -> true
      _ -> parent == "mjml"
    end
  end

  defp text_parent?(_parent), do: false

  # Points at the first character that isn't whitespace or part of a comment. Text nodes
  # from the parser carry their start; otherwise fall back to the given location.
  defp text_location(text, meta, fallback \\ %{line: 1, column: 1})

  defp text_location(text, %{line: line, column: column} = meta, _fallback) do
    skipped = text |> String.replace(~r/<!--.*?-->/s, &String.duplicate(" ", String.length(&1))) |> leading_space()

    location =
      case String.split(skipped, "\n") do
        [same_line] -> %{line: line, column: column + String.length(same_line)}
        lines -> %{line: line + length(lines) - 1, column: String.length(List.last(lines)) + 1}
      end

    Map.merge(location, Map.take(meta, [:file]))
  end

  defp text_location(_text, _meta, fallback), do: fallback

  defp leading_space(text) do
    [leading] = Regex.run(~r/^\s*/, text)
    leading
  end

  # Only ASCII whitespace is ignored; mrml renders other spaces, such as U+00A0
  defp stray_text?({:text, text, _meta}) do
    text
    |> String.replace(~r/<!--.*?-->/s, "")
    |> String.trim(" ")
    |> String.split(["\n", "\r", "\t", " "], trim: true)
    |> Kernel.!=([])
  end

  defp stray_text?(_node), do: false

  ## Elements

  defp validate_element(node, %{in_ending: ending} = ctx, acc) when is_binary(ending) do
    name = element_name(node)

    acc =
      if Tags.mjml?(name) do
        [
          error(:ending_tag, ctx, element_meta(node),
            tag: name,
            message: "#{name} cannot be used inside #{ending}, whose content is HTML, not MJML"
          )
          | acc
        ]
      else
        acc
      end

    validate_children(element_children(node), ctx, acc)
  end

  defp validate_element(node, ctx, acc) do
    name = element_name(node)
    meta = element_meta(node)
    acc = check_lowercase(acc, node, ctx)

    cond do
      Map.has_key?(@unsupported_tags, name) ->
        # The children of unsupported tags are unsupported too, so they are not reported again
        [error(:unsupported_tag, ctx, meta, tag: name, message: @unsupported_tags[name]) | acc]

      Map.has_key?(@components, name) ->
        validate_component(node, name, @components[name], ctx, acc)

      name == "mjml" ->
        validate_mjml(node, ctx, acc)

      Map.has_key?(@elements, name) ->
        validate_overlay_element(node, name, @elements[name], ctx, acc)

      ctx.html_allowed and not Tags.mjml?(name) ->
        validate_children(element_children(node), child_ctx(ctx, name, meta), acc)

      true ->
        acc = [unknown_tag_error(name, meta, ctx) | acc]
        validate_children(element_children(node), child_ctx(ctx, name, meta), acc)
    end
  end

  defp validate_component(node, name, component, ctx, acc) do
    meta = element_meta(node)
    attrs = element_attrs(node)

    allowed =
      component.allowed_attributes
      |> Map.keys()
      |> Kernel.++(@global_attributes)
      |> Kernel.++(mjml_eex_attributes(name))

    acc =
      acc
      |> check_nesting(name, meta, ctx)
      |> check_supported_placement(name, meta, ctx)
      |> check_attributes(name, attrs, allowed, ctx)
      |> check_types(name, attrs, component.allowed_attributes, ctx)
      |> check_unsupported_values(name, attrs, ctx)
      |> check_empty_title(name, node, ctx)
      |> check_content(name, node, content_restriction(name, ctx), ctx)

    child_ctx = child_ctx(ctx, name, meta)
    child_ctx = if component.ending_tag, do: %{child_ctx | in_ending: name}, else: child_ctx

    validate_children(element_children(node), child_ctx, acc)
  end

  defp validate_mjml(node, %{parent: :root} = ctx, acc) do
    meta = element_meta(node)
    %{allowed_attributes: allowed} = @elements["mjml"]
    attrs = element_attrs(node)

    acc =
      acc
      |> check_attributes("mjml", attrs, Map.keys(allowed) ++ mjml_eex_attributes("mjml"), ctx)
      |> check_types("mjml", attrs, allowed, ctx)
      |> check_unsupported_values("mjml", attrs, ctx)
      |> check_single_children(node, ctx)

    validate_children(element_children(node), child_ctx(ctx, "mjml", meta), acc)
  end

  defp validate_mjml(node, ctx, acc) do
    meta = element_meta(node)
    acc = [error(:root, ctx, meta, tag: "mjml", message: "mjml must be the root element") | acc]
    validate_children(element_children(node), child_ctx(ctx, "mjml", meta), acc)
  end

  defp validate_overlay_element(node, name, element, ctx, acc) do
    meta = element_meta(node)
    attrs = element_attrs(node)

    {allowed_names, typed} =
      case element.allowed_attributes do
        :any_component_attribute ->
          {@any_component_attributes ++ @global_attributes ++ element.required_attributes, %{}}

        allowed ->
          {Map.keys(allowed), allowed}
      end

    allowed_names = allowed_names ++ mjml_eex_attributes(name)

    acc =
      acc
      |> check_attribute_context(name, meta, ctx)
      |> check_attributes(name, attrs, allowed_names, ctx)
      |> check_types(name, attrs, typed, ctx)
      |> check_required(name, attrs, element.required_attributes, meta, ctx)
      |> check_content(name, node, content_restriction(name, ctx), ctx)

    # The children of mj-class set per-tag defaults, so they are not nested like normal tags
    child_parent = if name == "mj-class", do: nil, else: name
    validate_children(element_children(node), %{child_ctx(ctx, name, meta) | parent: child_parent}, acc)
  end

  # mj-all and mj-class only mean something inside mj-attributes (the parent of a fragment
  # isn't known)
  defp check_attribute_context(acc, name, meta, ctx) when name in ["mj-all", "mj-class"] do
    if ctx.parent in ["mj-attributes", nil] do
      acc
    else
      [error(:invalid_child, ctx, meta, tag: name, message: "#{name} can only be used inside mj-attributes") | acc]
    end
  end

  defp check_attribute_context(acc, _name, _meta, _ctx), do: acc

  defp child_ctx(ctx, name, meta), do: Map.merge(ctx, %{parent: name, parent_meta: meta})

  ## Rules

  # mjml-validator's validChildren rule. Only components inside components (or the root)
  # are checked, and like MJML, a component without an entry in the dependency map
  # (such as mj-font) allows no children. MJML skips the <mjml> root, so problems
  # directly under it are :root errors.
  defp check_nesting(acc, name, meta, %{parent: parent} = ctx) when is_binary(parent) do
    allowed =
      cond do
        Map.has_key?(@dependencies, parent) -> @dependencies[parent]
        Map.has_key?(@components, parent) -> []
        true -> :any
      end

    cond do
      allowed == :any or name in allowed ->
        acc

      parent == "mjml" ->
        [
          error(:root, ctx, meta,
            tag: name,
            message: "#{name} cannot be used inside mjml, which only accepts #{Enum.join(allowed, ", ")}"
          )
          | acc
        ]

      true ->
        [
          error(:invalid_child, ctx, meta,
            tag: name,
            message: "#{name} cannot be used inside #{parent}, only inside: #{Enum.join(valid_parents(name), ", ")}"
          )
          | acc
        ]
    end
  end

  defp check_nesting(acc, _name, _meta, _ctx), do: acc

  # Placements MJML allows but mrml rejects
  defp check_supported_placement(acc, name, meta, %{parent: parent} = ctx) do
    if parent in Map.get(@unsupported_children, name, []) do
      [
        error(:unsupported_tag, ctx, meta, tag: name, message: "#{name} inside #{parent} is not supported by #{@mrml}")
        | acc
      ]
    else
      acc
    end
  end

  # Content MJML allows but mrml rejects: in some ending tags (see Overlay.content_restrictions/0),
  # and in the tags that set default attributes, mj-attributes' children, mj-all and mj-class
  # (MJML 5's per-class defaults with child tags aren't supported)
  defp content_restriction(name, ctx) do
    cond do
      ctx.parent == "mj-attributes" -> :empty
      name in ["mj-all", "mj-class"] -> :empty
      true -> Map.get(@content_restrictions, name)
    end
  end

  defp check_content(acc, _name, _node, nil, _ctx), do: acc

  defp check_content(acc, name, node, restriction, ctx) do
    node
    |> element_children()
    |> flatten()
    |> Enum.reduce(acc, &check_content_node(&1, name, restriction, ctx, &2))
  end

  defp check_content_node({:text, text, meta}, name, restriction, ctx, acc) do
    problem =
      case restriction do
        :empty -> if String.trim(text) != "", do: {text_location(text, meta), "Content inside #{name} is"}
        :text -> location_of(text, "<!--", meta, ctx, "HTML comments inside #{name} are")
        :no_markup -> location_of(text, "<", meta, ctx, "< inside #{name} is")
        :text_and_comments -> nil
      end

    case problem do
      {location, subject} ->
        [error(:unexpected_text, ctx, location, tag: name, message: "#{subject} not supported by #{@mrml}") | acc]

      nil ->
        acc
    end
  end

  defp check_content_node({:block, :tag, _, _, _, _, _} = node, name, restriction, ctx, acc),
    do: check_content_element(node, name, restriction, ctx, acc)

  defp check_content_node({:self_close, :tag, _, _, _} = node, name, restriction, ctx, acc),
    do: check_content_element(node, name, restriction, ctx, acc)

  # Expressions can only be checked when they're rendered, except where nothing is allowed
  defp check_content_node({type, _expr, meta}, name, :empty, ctx, acc) when type in [:body_expr, :eex] do
    [
      error(:unexpected_text, ctx, meta, tag: name, message: "Content inside #{name} is not supported by #{@mrml}")
      | acc
    ]
  end

  defp check_content_node(_node, _name, _restriction, _ctx, acc), do: acc

  # MJML tags in ending tags are :ending_tag errors already
  defp check_content_element(node, name, restriction, ctx, acc) do
    element = element_name(node)

    cond do
      Tags.mjml?(element) and ending_tag?(name) ->
        acc

      restriction == :empty ->
        message = "#{element} inside #{name} is not supported by #{@mrml}"
        [error(:unsupported_tag, ctx, element_meta(node), tag: element, message: message) | acc]

      restriction in [:text, :text_and_comments] ->
        message = "<#{element}> inside #{name} is not supported by #{@mrml}, which only accepts text there"
        [error(:unsupported_tag, ctx, element_meta(node), tag: element, message: message) | acc]

      true ->
        acc
    end
  end

  # mrml parses HTML comments more strictly than MJML (see Overlay.comment_parents/0)
  defp check_comments(text, meta, ctx, acc) do
    cond do
      not String.contains?(text, "<!--") ->
        acc

      problem = dashes_in_comment(text) ->
        {index, subject} = problem
        [comment_error(text, index, meta, ctx, subject) | acc]

      # In ending tags, mj-raw, component content and fragments, comments are fine
      ctx.in_ending != nil or not is_binary(ctx.parent) or ctx.html_allowed ->
        acc

      match = Regex.run(~r/<!--(?:\[if|<!\[endif\])/, text, return: :index) ->
        [{index, _length}] = match
        subject = "Conditional comments directly inside #{ctx.parent} are"
        [comment_error(text, index, meta, ctx, subject <> " not supported by #{@mrml}. Put them in an mj-raw") | acc]

      ctx.parent not in @comment_parents ->
        {index, _length} = :binary.match(text, "<!--")

        [
          comment_error(text, index, meta, ctx, "HTML comments inside #{ctx.parent} are not supported by #{@mrml}")
          | acc
        ]

      true ->
        acc
    end
  end

  defp dashes_in_comment(text) do
    ~r/<!--(.*?)-->/s
    |> Regex.scan(text, return: :index)
    |> Enum.find_value(fn [{start, _length}, {body_start, body_length}] ->
      if String.contains?(binary_part(text, body_start, body_length), "--"),
        do: {start, "HTML comments that contain -- are not supported by #{@mrml}"}
    end)
  end

  defp comment_error(text, index, meta, ctx, message) do
    error(:unexpected_text, ctx, location_at(text, index, meta, ctx), tag: ctx.parent, message: message)
  end

  # mrml's tags are case-sensitive: it outputs <mj-Text> as an HTML element
  defp check_lowercase(acc, node, ctx) do
    raw = raw_element_name(node)
    name = String.downcase(raw)

    if raw != name and Tags.mjml?(name) do
      message = "#{raw} is not supported by #{@mrml}, whose tags are lowercase"

      [
        error(:unsupported_tag, ctx, element_meta(node), tag: raw, message: message, hint: ~s(did you mean "#{name}"?))
        | acc
      ]
    else
      acc
    end
  end

  # The location of the first `pattern` in a text node, with the subject of the message
  defp location_of(text, pattern, meta, ctx, subject) do
    case :binary.match(text, pattern) do
      {index, _length} -> {location_at(text, index, meta, ctx), subject}
      :nomatch -> nil
    end
  end

  # The location of a byte index in a text node
  defp location_at(text, index, meta, ctx) do
    meta = if Map.has_key?(meta, :line), do: meta, else: Map.merge(meta, ctx.parent_meta)
    before = binary_part(text, 0, index)

    location =
      case String.split(before, "\n") do
        [same_line] -> %{line: meta.line, column: meta.column + String.length(same_line)}
        lines -> %{line: meta.line + length(lines) - 1, column: String.length(List.last(lines)) + 1}
      end

    Map.merge(location, Map.take(meta, [:file]))
  end

  defp valid_parents(name) do
    Enum.filter(@dependency_order, fn parent ->
      case @dependencies[parent] do
        :any -> true
        children -> name in children
      end
    end)
  end

  # mjml-validator's validAttributes rule, reported per attribute. Duplicates are reported too.
  defp check_attributes(acc, tag, attrs, allowed, ctx) do
    {acc, _seen} =
      attrs
      |> Enum.reject(&special_attribute?/1)
      |> Enum.reduce({acc, MapSet.new()}, fn {name, _value, meta}, {acc, seen} ->
        acc =
          cond do
            MapSet.member?(seen, name) ->
              [
                error(:duplicate_attribute, ctx, meta,
                  tag: tag,
                  attribute: name,
                  message: "Attribute #{name} is duplicated"
                )
                | acc
              ]

            name in allowed ->
              acc

            true ->
              [
                error(:unknown_attribute, ctx, meta,
                  tag: tag,
                  attribute: name,
                  message: "Attribute #{name} is illegal",
                  hint: suggestion(name, allowed)
                )
                | acc
              ]
          end

        {acc, MapSet.put(seen, name)}
      end)

    acc
  end

  # mjml-validator's validTypes rule. Expression values are not checked.
  defp check_types(acc, tag, attrs, types, ctx) do
    Enum.reduce(attrs, acc, fn {name, value, meta}, acc ->
      with {:ok, type} <- Map.fetch(types, name),
           {:ok, string} <- literal_value(value),
           message when is_binary(message) <- Types.error_message(type, string) do
        [error(:invalid_value, ctx, meta, tag: tag, attribute: name, message: "Attribute #{name} #{message}") | acc]
      else
        _ -> acc
      end
    end)
  end

  defp check_unsupported_values(acc, tag, attrs, ctx) do
    Enum.reduce(Overlay.attribute_value_warnings(), acc, fn
      {^tag, attribute, value, reason}, acc ->
        case Enum.find(attrs, fn {name, attr_value, _meta} ->
               name == attribute and (value == :any or literal_value(attr_value) == {:ok, value})
             end) do
          {_name, _value, meta} ->
            [error(:unsupported_value, ctx, meta, tag: tag, attribute: attribute, message: reason) | acc]

          nil ->
            acc
        end

      _warning, acc ->
        acc
    end)
  end

  # A {...} spread may provide them
  defp check_required(acc, tag, attrs, required, meta, ctx) do
    present = for {name, _value, _meta} <- attrs, do: name
    required = if :root in present, do: [], else: required

    Enum.reduce(required -- present, acc, fn attribute, acc ->
      [
        error(:missing_attribute, ctx, meta,
          tag: tag,
          attribute: attribute,
          message: "#{tag} requires the #{attribute} attribute"
        )
        | acc
      ]
    end)
  end

  # Adapted from mjml-validator's requiredTitle rule, which MJML 5.4.1 ships but does
  # not register, so MJML itself never reports it
  defp check_empty_title(acc, "mj-head", node, ctx) do
    case Enum.find(flatten(element_children(node)), &(element?(&1) and element_name(&1) == "mj-title")) do
      nil ->
        acc

      title ->
        children = flatten(element_children(title))

        if Enum.all?(children, &match?({:text, _, _}, &1)) and
             children |> Enum.map_join(fn {:text, text, _} -> text end) |> String.trim() == "" do
          [
            error(:empty_title, ctx, element_meta(title),
              tag: "mj-title",
              message: "Empty mj-title. Provide non-empty content for a valid <title>."
            )
            | acc
          ]
        else
          acc
        end
    end
  end

  defp check_empty_title(acc, _name, _node, _ctx), do: acc

  # Elements with :if or :for, and the clauses of EEx blocks, are alternatives, so only
  # elements that are always rendered count
  defp check_single_children(acc, node, ctx) do
    node
    |> element_children()
    |> unconditional_elements()
    |> Enum.filter(&(element_name(&1) in ["mj-head", "mj-body"]))
    |> Enum.group_by(&element_name/1)
    |> Enum.flat_map(fn {name, [_first | extra]} ->
      Enum.map(extra, &error(:root, ctx, element_meta(&1), tag: name, message: "mjml can only contain one #{name}"))
    end)
    |> Kernel.++(acc)
  end

  defp unconditional_elements(nodes) do
    Enum.filter(nodes, fn node ->
      element?(node) and
        not Enum.any?(element_attrs(node), &match?({special, _, _} when special in [":if", ":for"], &1))
    end)
  end

  # Warn about mj-class names that mj-attributes doesn't define. This needs the whole
  # document: it's skipped for fragments, documents with mj-include, and dynamic names.
  defp check_class_references(errors, nodes, ctx) do
    elements = all_elements(nodes)
    names = Enum.map(elements, &element_name/1)

    defined =
      for node <- elements, element_name(node) == "mj-class", {"name", value, _} <- element_attrs(node), do: value

    used =
      for node <- elements, {"mj-class", value, meta} <- element_attrs(node), do: {node, value, meta}

    dynamic? = Enum.any?(defined ++ Enum.map(used, &elem(&1, 1)), &(literal_value(&1) == :error))

    if "mj-include" in names or dynamic? or dynamic_head?(nodes) do
      errors
    else
      defined = MapSet.new(defined, fn value -> value |> literal_value() |> elem(1) end)

      for {node, value, meta} <- used,
          {:ok, string} = literal_value(value),
          class <- String.split(string),
          not MapSet.member?(defined, class),
          reduce: errors do
        errors ->
          [
            error(:unknown_class, ctx, meta,
              tag: element_name(node),
              attribute: "mj-class",
              message: "mj-class #{class} is not defined in mj-attributes"
            )
            | errors
          ]
      end
    end
  end

  @doc """
  Checks one attribute value of an MJML tag, for runtime validation of values that come
  from expressions. Returns `nil` if the value is fine (or the tag isn't known).
  """
  @spec check_attribute(String.t(), String.t(), String.t()) :: ValidationError.t() | nil
  def check_attribute(tag, name, value) do
    check_attribute_value(tag, name, value) || check_unsupported_value(tag, name, value)
  end

  # An attribute or value mjml_nif ignores or handles differently from MJML (the
  # :unsupported_value rule), such as full-width="false"
  defp check_unsupported_value(tag, name, value) do
    Enum.find_value(Overlay.attribute_value_warnings(), fn
      {^tag, ^name, expected, reason} when expected in [:any, value] ->
        %ValidationError{rule: :unsupported_value, severity: :error, tag: tag, attribute: name, message: reason}

      _warning ->
        nil
    end)
  end

  defp check_attribute_value(tag, name, value) do
    case attribute_spec(tag) do
      {allowed, types} ->
        cond do
          name not in allowed ->
            %ValidationError{
              rule: :unknown_attribute,
              severity: :error,
              tag: tag,
              attribute: name,
              message: "Attribute #{name} is illegal",
              hint: suggestion(name, allowed)
            }

          message = types[name] && Types.error_message(types[name], value) ->
            %ValidationError{
              rule: :invalid_value,
              severity: :error,
              tag: tag,
              attribute: name,
              message: "Attribute #{name} #{message}"
            }

          true ->
            nil
        end

      nil ->
        nil
    end
  end

  @doc false
  # The attribute names an MJML tag accepts, or nil for an unknown tag
  @spec attribute_names(String.t()) :: [String.t()] | nil
  def attribute_names(tag) do
    case attribute_spec(tag) do
      {allowed, _types} -> allowed
      nil -> nil
    end
  end

  defp attribute_spec(tag) do
    cond do
      component = @components[tag] ->
        allowed = Map.keys(component.allowed_attributes) ++ @global_attributes ++ mjml_eex_attributes(tag)
        {allowed, component.allowed_attributes}

      element = @elements[tag] ->
        case element.allowed_attributes do
          :any_component_attribute ->
            {@any_component_attributes ++ @global_attributes ++ element.required_attributes, %{}}

          allowed ->
            {Map.keys(allowed) ++ mjml_eex_attributes(tag), allowed}
        end

      true ->
        nil
    end
  end

  # Classes could be defined by an expression in mj-head, which can't be seen here
  defp dynamic_head?(nodes) do
    nodes
    |> all_elements()
    |> Enum.filter(&(element_name(&1) == "mj-head"))
    |> Enum.any?(&contains_expression?(element_children(&1)))
  end

  # Expressions inside ending tags (such as mj-title) can't define classes
  defp contains_expression?(nodes) do
    Enum.any?(nodes, fn
      {type, _, _} when type in [:body_expr, :eex] ->
        true

      {:eex_block, _, _, _} ->
        true

      # Components and slots can render anything, such as an mj-attributes
      {kind, type, _, _, _, _, _} when kind == :block and type in [:local_component, :remote_component, :slot] ->
        true

      {:self_close, type, _, _, _} when type in [:local_component, :remote_component, :slot] ->
        true

      node ->
        element?(node) and not ending_tag?(element_name(node)) and contains_expression?(element_children(node))
    end)
  end

  defp ending_tag?(name), do: match?(%{^name => %{ending_tag: true}}, @components)

  defp unknown_tag_error(name, meta, ctx) do
    hint =
      if Tags.mjml?(name) do
        suggestion(name, @suggested_tags)
      else
        "HTML is only allowed inside ending tags such as mj-text, and inside mj-raw"
      end

    error(:unknown_tag, ctx, meta, tag: name, message: "Element #{name} doesn't exist or is not registered", hint: hint)
  end

  ## Helpers

  # mjml-raw-text only means something on mj-raw
  defp mjml_eex_attributes("mj-raw"), do: Tags.mjml_eex_attributes()
  defp mjml_eex_attributes(_name), do: Tags.mjml_eex_attributes() -- [Tags.raw_text_attribute()]

  # :if, :for, :let and {...} root attributes
  defp special_attribute?({:root, _value, _meta}), do: true
  defp special_attribute?({":" <> _, _value, _meta}), do: true
  defp special_attribute?(_attr), do: false

  # A missing value (`<mj-x attr>`) is an empty string to MJML
  defp literal_value(nil), do: {:ok, ""}
  defp literal_value({:string, string, _meta}), do: {:ok, string}
  defp literal_value(_value), do: :error

  @doc false
  def suggestion(name, candidates) do
    case @aliases do
      %{^name => alias} -> if alias in candidates, do: ~s(did you mean "#{alias}"?), else: closest(name, candidates)
      _ -> closest(name, candidates)
    end
  end

  defp closest(name, candidates) do
    candidates
    |> Enum.map(&{&1, String.jaro_distance(name, &1)})
    |> Enum.filter(fn {_candidate, distance} -> distance >= 0.8 end)
    |> Enum.max_by(fn {_candidate, distance} -> distance end, fn -> nil end)
    |> case do
      {candidate, _distance} -> ~s(did you mean "#{candidate}"?)
      nil -> nil
    end
  end

  defp all_elements(nodes) do
    nodes
    |> flatten()
    |> Enum.flat_map(fn node ->
      if element?(node), do: [node | all_elements(element_children(node))], else: []
    end)
  end

  defp element?({:block, :tag, _, _, _, _, _}), do: true
  defp element?({:self_close, :tag, _, _, _}), do: true
  defp element?(_node), do: false

  defp raw_element_name({:block, _, name, _, _, _, _}), do: name
  defp raw_element_name({:self_close, _, name, _, _}), do: name

  defp element_name({:block, _, name, _, _, _, _}), do: String.downcase(name)
  defp element_name({:self_close, _, name, _, _}), do: String.downcase(name)

  defp element_attrs({:block, _, _, attrs, _, _, _}), do: attrs
  defp element_attrs({:self_close, _, _, attrs, _}), do: attrs

  defp element_children({:block, _, _, _, children, _, _}), do: children
  defp element_children({:self_close, _, _, _, _}), do: []

  defp element_meta({:block, _, _, _, _, meta, _}), do: meta
  defp element_meta({:self_close, _, _, _, meta}), do: meta

  defp error(rule, ctx, meta, fields) do
    severity = Map.get(ctx.levels, rule, :error)

    struct!(
      ValidationError,
      # Nodes from another file (a layout's) carry their own file
      [rule: rule, severity: severity, file: Map.get(meta, :file, ctx.file), line: meta.line, column: meta.column] ++
        fields
    )
  end
end
