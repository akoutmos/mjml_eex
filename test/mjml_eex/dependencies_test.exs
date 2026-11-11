defmodule MjmlEEx.DependenciesTest do
  # Compiler tracers are a global setting
  use ExUnit.Case, async: false

  # Mix recompiles a module when a module it references outside of its functions changes (a
  # compile-time dependency), and through those, when anything that module calls changes. This
  # tracer reports those references.
  defmodule Tracer do
    @moduledoc false

    def trace({:alias_reference, _meta, module}, %Macro.Env{function: nil} = env), do: report(env.module, module)

    def trace({kind, _meta, module, _name, _arity}, %Macro.Env{function: nil} = env)
        when kind in [:remote_function, :remote_macro],
        do: report(env.module, module)

    def trace({:compile_env, app, path, _return}, env) do
      if pid = :persistent_term.get(__MODULE__, nil), do: send(pid, {:compile_env, env.module, app, path})
      :ok
    end

    def trace(_event, _env), do: :ok

    defp report(from, to) do
      if pid = :persistent_term.get(__MODULE__, nil), do: send(pid, {:compile_time, from, to})
      :ok
    end
  end

  defmodule Layout do
    use MjmlEEx

    def render(assigns), do: ~MJML"<mjml><mj-body>{@inner_content}</mj-body></mjml>"
  end

  defp compile_traced(code, file) do
    tracers = Code.get_compiler_option(:tracers)
    :persistent_term.put(Tracer, self())
    Code.put_compiler_option(:tracers, [Tracer | tracers])

    try do
      Code.compile_string(code, file)
    after
      Code.put_compiler_option(:tracers, tracers)
      :persistent_term.erase(Tracer)
    end
  end

  test "an email's layout is a runtime dependency" do
    [{module, _binary}] =
      compile_traced(
        """
        defmodule MjmlEEx.DependenciesTest.WithLayout do
          use MjmlEEx, layout: MjmlEEx.DependenciesTest.Layout

          def render(assigns), do: ~MJML"<mj-section><mj-column><mj-text>Hi</mj-text></mj-column></mj-section>"
        end
        """,
        "with_layout.ex"
      )

    refute_received {:compile_time, MjmlEEx.DependenciesTest.WithLayout, MjmlEEx.DependenciesTest.Layout}
    assert module.to_html(%{}) =~ "Hi"
  end

  test "emails and components are compiled again when the validation config changes" do
    compile_traced(
      """
      defmodule MjmlEEx.DependenciesTest.ConfigEmail do
        use MjmlEEx

        def render(assigns), do: ~MJML"<mj-text>Hi</mj-text>"
      end

      defmodule MjmlEEx.DependenciesTest.ConfigComponents do
        use MjmlEEx.Component

        def box(assigns), do: ~MJML"<mj-text>Box</mj-text>"
      end
      """,
      "config.ex"
    )

    # Mix records these reads, and compiles the modules again when the config changes
    assert_received {:compile_env, MjmlEEx.DependenciesTest.ConfigEmail, :mjml_eex, [:validation]}
    assert_received {:compile_env, MjmlEEx.DependenciesTest.ConfigComponents, :mjml_eex, [:validation]}
  end

  test "the components a template file calls are runtime dependencies" do
    dir = Path.join(System.tmp_dir!(), "mjml_eex_dependencies_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    File.write!(Path.join(dir, "file_email.meex"), """
    <mjml><mj-body><mj-section><mj-column>
      <MjmlEEx.Test.Components.cta href="https://example.com">Go</MjmlEEx.Test.Components.cta>
    </mj-column></mj-section></mj-body></mjml>
    """)

    [{module, _binary}] =
      compile_traced(
        "defmodule MjmlEEx.DependenciesTest.FileEmail do\n  use MjmlEEx\nend",
        Path.join(dir, "file_email.ex")
      )

    refute_received {:compile_time, MjmlEEx.DependenciesTest.FileEmail, MjmlEEx.Test.Components}
    assert module.to_html(%{}) =~ "https://example.com"
  end
end
