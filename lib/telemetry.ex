defmodule MjmlEEx.Telemetry do
  @moduledoc """
  Telemetry integration for event metrics, logging and error reporting.

  ### Render events

  MJML EEx emits the following telemetry events whenever a template is rendered:

  * `[:mjml_eex, :render, :start]` - When the rendering process has begun
  * `[:mjml_eex, :render, :stop]` - When the rendering process has successfully completed
  * `[:mjml_eex, :render, :exception]` - When the rendering process resulted in an error

  The render events contain the following measurements and metadata:

  | event        | measures       | metadata                                                                                                                       |
  | ------------ | ---------------| ------------------------------------------------------------------------------------------------------------------------------ |
  | `:start`     | `:system_time` | `:compiler`, `:mode`, `:assigns`, `:mjml_template`, `:mjml_template_file`, `:layout_module`                                    |
  | `:stop`      | `:duration`    | `:compiler`, `:mode`, `:assigns`, `:mjml_template`, `:mjml_template_file`, `:layout_module`                                    |
  | `:exception` | `:duration`    | `:compiler`, `:mode`, `:assigns`, `:mjml_template`, `:mjml_template_file`, `:layout_module`, `:kind`, `:reason`, `:stacktrace` |
  """

  require Logger

  @logger_event_id "mjml_eex_default_logger"

  @doc """
  This function attaches a Telemetry debug handler to MJML EEx so that you can
  see what emails are being rendered, under what conditions, and what the
  resulting HTML looks like. This is primarily used for debugging purposes
  but can be modified for use in production if you need to.
  """
  def attach_logger(opts \\ []) do
    events = [
      [:mjml_eex, :render, :start],
      [:mjml_eex, :render, :stop],
      [:mjml_eex, :render, :exception]
    ]

    opts = Keyword.put_new(opts, :level, :debug)

    :telemetry.attach_many(@logger_event_id, events, &__MODULE__.handle_event/4, opts)
  end

  @doc """
  Detach the debugging logger so that log messages are no longer produced.
  """
  def detach_logger do
    :telemetry.detach(@logger_event_id)
  end

  @doc false
  def handle_event([:mjml_eex, :render, event], measurements, metadata, opts) do
    level = Keyword.fetch!(opts, :level)

    Logger.log(level, "Event: #{inspect(event)}")
    Logger.log(level, "Measurements: #{inspect(measurements)}")
    Logger.log(level, "Metadata: #{inspect(metadata, printable_limit: :infinity)}")
  end
end
