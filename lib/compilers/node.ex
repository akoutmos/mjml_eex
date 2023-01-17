if Code.ensure_loaded?(:exec) do
  defmodule MjmlEEx.Compilers.Node do
    @moduledoc """
    This module implements the `MjmlEEx.Compiler` behaviour
    and allows you to compile your MJML templates using the Node
    CLI tool. This compiler expects you to have the `mjml` Node
    script accessible from the running environment.

    For information regarding the Node mjml compiler see:
    https://documentation.mjml.io/#command-line-interface

    ## Configuration

    In order to use this compiler, you need to set your application
    configration like so (in your `config.exs` file for example):

    ```elixir
    config :mjml_eex,
      compiler: MjmlEEx.Compilers.Node,
      compiler_opts: [
        timeout: 10_000,
        path: "mjml"
    ]
    ```

    In addition, since the Node compiler is run via `:erlexec`, you will
    need to add this optional dependency to your `mix.exs` file and also
    start the optional application:

    ```elixir
    def application do
      [
        extra_applications: [..., :erlexec]
      ]
    end

    defp deps do
      [
        ...
        {:erlexec, "~> 2.0"}
      ]
    end
    ```
    """

    @behaviour MjmlEEx.Compiler

    @impl true
    def compile(mjml_template) do
      # Get the configs for the compiler
      compiler_opts = Application.get_env(:mjml_eex, :compiler_opts)
      timeout = Keyword.get(compiler_opts, :timeout, 10_000)
      compiler_path = Keyword.get(compiler_opts, :path, "mjml")

      # Start the erlexec port
      {:ok, pid, os_pid} =
        :exec.run("#{compiler_path} -s -i --noStdoutFileComment", [:stdin, :stdout, :stderr, :monitor])

      # Send the MJML template to the compiler via STDIN
      :exec.send(pid, mjml_template)
      :exec.send(pid, :eof)

      # Initial state for reduce
      initial_reduce_results = %{
        stdout: "",
        stderr: []
      }

      result =
        [nil]
        |> Stream.cycle()
        |> Enum.reduce_while(initial_reduce_results, fn _, acc ->
          receive do
            {:DOWN, ^os_pid, _, ^pid, {:exit_status, exit_status}} when exit_status != 0 ->
              error = "Node mjml CLI compiler exited with status code #{inspect(exit_status)}"
              existing_errors = Map.get(acc, :stderr, [])
              {:halt, Map.put(acc, :stderr, [error | existing_errors])}

            {:DOWN, ^os_pid, _, ^pid, _} ->
              {:halt, acc}

            {:stderr, ^os_pid, error} ->
              error = String.trim(error)
              existing_errors = Map.get(acc, :stderr, [])
              {:cont, Map.put(acc, :stderr, [error | existing_errors])}

            {:stdout, ^os_pid, compiled_template_fragment} ->
              aggregated_template = Map.get(acc, :stdout, "")
              {:cont, Map.put(acc, :stdout, aggregated_template <> compiled_template_fragment)}
          after
            timeout ->
              :exec.kill(os_pid, :sigterm)
              time_in_seconds = System.convert_time_unit(timeout, :millisecond, :second)
              error = "Node mjml CLI compiler timed out after #{time_in_seconds} second(s)"
              existing_errors = Map.get(acc, :stderr, [])
              {:halt, Map.put(acc, :stderr, [error | existing_errors])}
          end
        end)

      case result do
        %{stderr: [], stdout: compiled_template} ->
          {:ok, compiled_template}

        %{stderr: errors} ->
          {:error, Enum.join(errors, "\n")}
      end
    end
  end
else
  defmodule MjmlEEx.Compilers.Node do
    @moduledoc false

    @behaviour MjmlEEx.Compiler

    @impl true
    def compile(_mjml_template) do
      raise("""
      In order to use the Node compiler you must also update your mix.exs file like so:

      def application do
      [
        extra_applications: [..., :erlexec]
      ]
      end

      defp deps do
      [
        ...
        {:erlexec, "~> 2.0"}
      ]
      end
      """)
    end
  end
end
