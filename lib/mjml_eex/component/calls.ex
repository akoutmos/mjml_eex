defmodule MjmlEEx.Component.Calls do
  @moduledoc false

  # Checks component calls in templates against the components' attr and slot
  # declarations: unknown and missing attributes and slots, and literal values against
  # their declared types and :values. :global attributes with `for: "mj-tag"` accept that
  # tag's attributes and are checked against its types.
  #
  # A call is checked while its template compiles when the declarations are already known
  # (the component's module is compiled, or it's defined earlier in the same module), and
  # errors fail the compilation right away.
  #
  # Calls in template modules (use MjmlEEx and use MjmlEEx.Component) are also recorded and
  # checked again by @after_verify, once every module is compiled. Elixir runs it again when
  # a module the template calls changes, so changing a component's declarations rechecks
  # the calls to it without recompiling the templates. Warnings are only reported there, so
  # they go away when the problem is fixed.

  alias MjmlEEx.{ValidationError, Validator}

  @global_attributes ["mj-class", "css-class"]

  # A call recorded by the compiler: the component's module and function, where it's
  # called, its attributes as {name, line, column, {:literal, value} | :expr}, whether it
  # has {...} spreads, and its slots
  @type call :: %{
          module: module(),
          fun: atom(),
          display: String.t(),
          file: String.t(),
          line: pos_integer(),
          column: pos_integer(),
          root: boolean(),
          attrs: [{atom(), pos_integer(), pos_integer(), {:literal, term()} | :expr}],
          slots: [map()],
          inner_block: boolean(),
          levels: map()
        }

  ## Compile time

  @doc false
  # Checks the call now if its component's declarations are known. With `recorded?`, the call
  # is checked again by @after_verify, so only errors are reported now.
  def check_now(call, caller, recorded?) do
    case declarations(call, caller) do
      {:ok, component} ->
        problems = check(call, component)
        problems = if recorded?, do: Enum.filter(problems, &(&1.severity == :error)), else: problems
        report!(problems, :compile)

      _none_or_unknown ->
        :ok
    end
  end

  defp declarations(%{module: module, fun: fun}, caller) do
    cond do
      module == caller.module and Module.open?(module) ->
        case Module.get_attribute(module, :__mjml_eex_components__) do
          %{^fun => component} -> {:ok, component}
          _ -> :unknown
        end

      Code.ensure_loaded?(module) and function_exported?(module, :__components__, 0) ->
        case module.__components__() do
          %{^fun => component} -> {:ok, component}
          _ -> :none
        end

      true ->
        :unknown
    end
  end

  ## @after_verify

  @doc false
  def __verify__(module) do
    problems =
      for call <- module.__mjml_eex_calls__(),
          Code.ensure_loaded?(call.module),
          function_exported?(call.module, :__components__, 0),
          component = call.module.__components__()[call.fun],
          problem <- check(call, component),
          do: problem

    report!(problems, :after_verify)
  end

  ## Checks

  @doc false
  def check(call, component) do
    Enum.reject(attr_problems(call, component) ++ slot_problems(call, component), &(&1.severity == :skip))
  end

  defp attr_problems(call, %{attrs: declared}) do
    by_name = Map.new(declared, &{&1.name, &1})
    global = Enum.find(declared, &(&1.type == :global))

    given =
      Enum.flat_map(call.attrs, fn {name, line, column, value} ->
        case by_name do
          %{^name => %{type: :global}} -> []
          %{^name => attr} -> value_problems(call, attr, value, line, column)
          _ -> undeclared_attr_problems(call, global, declared, name, value, line, column)
        end
      end)

    missing =
      if call.root do
        []
      else
        given_names = Enum.map(call.attrs, &elem(&1, 0))

        for %{name: name, required: true} <- declared, name not in given_names do
          problem(call, :component_attribute, call.line, call.column,
            attribute: name,
            message: "missing required attribute #{name} for #{call.display}"
          )
        end
      end

    given ++ missing
  end

  defp value_problems(call, %{name: name, type: type, values: values}, {:literal, value}, line, column) do
    cond do
      not MjmlEEx.Component.type_matches?(type, value) ->
        [
          problem(call, :component_attribute, line, column,
            attribute: name,
            message: "attribute #{name} for #{call.display} must be of type #{inspect(type)}, got: #{inspect(value)}"
          )
        ]

      values != nil and value not in values ->
        [
          problem(call, :component_attribute, line, column,
            attribute: name,
            message: "attribute #{name} for #{call.display} must be one of #{inspect(values)}, got: #{inspect(value)}"
          )
        ]

      true ->
        []
    end
  end

  defp value_problems(_call, _attr, :expr, _line, _column), do: []

  defp undeclared_attr_problems(call, nil, declared, name, _value, line, column) do
    [unknown_attr(call, name, Enum.map(declared, &to_string(&1.name)), line, column)]
  end

  defp undeclared_attr_problems(call, global, declared, name, value, line, column) do
    allowed = global_attribute_names(global)
    string_name = to_string(name)

    cond do
      string_name not in allowed ->
        [unknown_attr(call, name, allowed ++ Enum.map(declared, &to_string(&1.name)), line, column)]

      # Names given with include: are the component's choice, whatever the for: tag accepts
      string_name in Enum.map(global.include, &to_string/1) ->
        []

      global.for && match?({:literal, _}, value) ->
        {:literal, literal} = value
        global_value_problems(call, global.for, string_name, literal, line, column)

      true ->
        []
    end
  end

  defp global_attribute_names(%{for: tag, include: include}) do
    tag_attributes =
      case tag && Validator.attribute_names(tag) do
        nil -> []
        names -> names
      end

    Enum.uniq(@global_attributes ++ Enum.map(include, &to_string/1) ++ tag_attributes)
  end

  defp global_value_problems(_call, _tag, _name, value, _line, _column) when value in [nil, false], do: []

  defp global_value_problems(call, tag, name, value, line, column) do
    value = if value == true, do: "true", else: to_string(value)

    case Validator.check_attribute(tag, name, value) do
      nil ->
        []

      error ->
        [
          problem(call, :component_attribute, line, column,
            attribute: name,
            message: "#{error.message} (for #{call.display})"
          )
        ]
    end
  end

  defp unknown_attr(call, name, candidates, line, column) do
    problem(call, :component_attribute, line, column,
      attribute: name,
      message: "unknown attribute #{name} for #{call.display}",
      hint: Validator.suggestion(to_string(name), candidates)
    )
  end

  defp slot_problems(call, %{slots: declared} = component) do
    by_name = Map.new(declared, &{&1.name, &1})
    given_names = Enum.map(call.slots, & &1.name)
    # Like Phoenix, a component without any declarations accepts anything
    declarations? = declared != [] or component.attrs != []

    unknown =
      for slot <- call.slots, not Map.has_key?(by_name, slot.name), declarations? do
        problem(call, :component_slot, slot.line, slot.column,
          message: "undefined slot #{slot.name} for #{call.display}",
          hint: Validator.suggestion(to_string(slot.name), Enum.map(declared, &to_string(&1.name)))
        )
      end

    missing =
      for %{name: name, required: true} <- declared,
          if(name == :inner_block, do: not call.inner_block, else: name not in given_names) do
        problem(call, :component_slot, call.line, call.column,
          message: "missing required slot #{name} for #{call.display}"
        )
      end

    # Only slots that declare attributes have them checked
    slot_attrs =
      Enum.flat_map(call.slots, fn slot ->
        case by_name[slot.name] do
          %{attrs: [_ | _] = attrs} -> slot_attr_problems(call, slot, attrs)
          _ -> []
        end
      end)

    unknown ++ missing ++ slot_attrs
  end

  defp slot_attr_problems(call, slot, declared) do
    slot_call = %{
      call
      | display: "<:#{slot.name}> in #{call.display}",
        attrs: slot.attrs,
        root: slot.root,
        line: slot.line,
        column: slot.column
    }

    attr_problems(slot_call, %{attrs: declared})
  end

  defp problem(call, rule, line, column, fields) do
    # Attribute names are strings, as in MJML validation errors
    fields = Keyword.replace_lazy(fields, :attribute, &to_string/1)

    struct!(
      ValidationError,
      [
        rule: rule,
        severity: Map.get(call.levels, rule, :error),
        tag: call.display,
        file: call.file,
        line: line,
        column: column
      ] ++
        fields
    )
  end

  ## Reporting

  defp report!([], _when), do: :ok

  defp report!(problems, phase) do
    {errors, warnings} = Enum.split_with(problems, &(&1.severity == :error))

    for warning <- warnings do
      IO.warn(describe(warning), file: warning.file, line: warning.line, column: warning.column)
    end

    case {errors, phase} do
      {[], _phase} ->
        :ok

      {[first | _], :compile} ->
        raise CompileError, file: first.file, line: first.line, description: summary(errors)

      {[first | _], :after_verify} ->
        # Raising here fails the build, but with a noisy trace, so the errors are printed as
        # diagnostics first and the exception only summarizes them
        for error <- errors, do: print_error(error)

        raise CompileError,
          file: first.file,
          line: first.line,
          description: "invalid component calls (see the errors above)"
    end
  end

  defp summary(errors) do
    count = if match?([_], errors), do: "1 error", else: "#{length(errors)} errors"
    "invalid component call (#{count}):\n\n" <> Enum.map_join(errors, "\n", &("    " <> Exception.message(&1))) <> "\n"
  end

  defp describe(%{message: message, hint: nil}), do: message
  defp describe(%{message: message, hint: hint}), do: "#{message} (#{hint})"

  defp print_error(error) do
    Code.print_diagnostic(%{
      severity: :error,
      message: describe(error),
      file: Path.expand(error.file),
      source: Path.expand(error.file),
      position: {error.line, error.column},
      span: nil,
      stacktrace: [],
      details: nil
    })
  end
end
