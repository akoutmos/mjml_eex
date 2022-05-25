defmodule MjmlEEx.Compilers.Node do
  @moduledoc """
  This module implements the `MjmlEEx.Compiler` behaviour
  and allows you to compile your MJML templates using the Node
  CLI tool. This compiler expects you to have the `mjml` Node
  script accessible from the running environment.

  For information regarding the Node mjml compiler see:
  https://documentation.mjml.io/#command-line-interface
  """

  @behaviour MjmlEEx.Compiler

  @impl true
  def compile(mjml_template) do
    # Start the erlexec port
    {:ok, pid, os_pid} = :exec.run("mjml -s -i --noStdoutFileComment", [:stdin, :stdout, :stderr, :monitor])

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
          {:DOWN, ^os_pid, _, ^pid, {:exit_status, exit_status}} ->
            error = "Node mjml CLI compiler exited with status code #{inspect(exit_status)}"
            existing_errors = Map.get(acc, :stderr, [])
            {:halt, Map.put(acc, :stderr, [error | existing_errors])}

          {:DOWN, ^os_pid, _, ^pid, _} ->
            {:halt, acc}

          {:stderr, ^os_pid, error} ->
            error = String.trim(error)
            existing_errors = Map.get(acc, :stderr, [])
            {:cont, Map.put(acc, :stderr, [error | existing_errors])}

          {:stdout, ^os_pid, compiled_template} ->
            {:cont, Map.put(acc, :stdout, compiled_template)}
        after
          10_000 ->
            :exec.kill(os_pid, :sigterm)
            error = "Node mjml CLI compiler timed out after 10 seconds"
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
