defmodule Mix.Tasks.MjmlEex.Gen.Screenshots do
  @shortdoc "Regenerates the screenshots of the prebuilt templates"

  @moduledoc """
  Regenerates the screenshots of the prebuilt templates in `guides/images/templates/`, and the
  gallery of them in `gallery.jpg`, from the examples in `screenshots/examples.exs`.

      mix mjml_eex.gen.screenshots
      mix mjml_eex.gen.screenshots welcome invoice

  With template names, such as `welcome` for `MjmlEEx.Templates.Welcome`, it only takes
  those screenshots, and leaves the gallery as it is.

  This is a dev-only task for macOS. It takes the screenshots with WebKit, the engine of Apple
  Mail and Safari, with `screenshots/snapshot.swift`, so it needs Swift, which comes with the
  Xcode command line tools. See `screenshots/README.md`.
  """

  use Mix.Task

  @dir "screenshots"
  @images_dir "guides/images/templates"

  # Emails are shown 680 CSS pixels wide, around the 600 pixel email, and saved at 1.5x, which
  # is sharp at the sizes the docs show them at
  @email_width 680
  @image_width 1020
  @quality 0.85

  # The gallery shows the top of each email, a row of five
  @gallery_columns 5
  @gallery_width 1600

  @impl Mix.Task
  def run(args) do
    unless match?({:unix, :darwin}, :os.type()) and System.find_executable("swift") do
      Mix.raise("mix mjml_eex.gen.screenshots needs macOS and Swift. Install Swift with: xcode-select --install")
    end

    Mix.Task.run("app.start")
    # Fail on invalid MJML, such as an attribute value from an assign that MJML doesn't accept
    Application.put_env(:mjml_eex, :runtime_validation, :raise)

    {%{art: art, templates: templates}, _binding} = Code.eval_file(Path.join(@dir, "examples.exs"))
    check_examples!(templates)

    work_dir = Path.join(Mix.Project.build_path(), "screenshots")
    File.rm_rf!(work_dir)
    File.mkdir_p!(work_dir)

    gallery = if args == [], do: [gallery_job(templates, work_dir)], else: []

    jobs =
      Enum.map(art, &art_job(&1, work_dir)) ++
        Enum.map(select(templates, args), &template_job(&1, work_dir)) ++ gallery

    jobs_file = Path.join(work_dir, "jobs.json")
    File.write!(jobs_file, JSON.encode!(%{root: File.cwd!(), jobs: jobs}))

    Mix.shell().info("Taking #{length(jobs)} screenshots with WebKit, which writes:")

    case System.cmd("swift", [Path.join(@dir, "snapshot.swift"), jobs_file], into: IO.stream(), stderr_to_stdout: true) do
      {_, 0} -> :ok
      {_, status} -> Mix.raise("#{@dir}/snapshot.swift exited with status #{status}")
    end
  end

  # Every template needs an example, so its screenshot can be taken and it's in the gallery
  defp check_examples!(templates) do
    {:ok, modules} = :application.get_key(:mjml_eex, :modules)
    template_modules = Enum.filter(modules, &match?(["MjmlEEx", "Templates", _], Module.split(&1)))

    case template_modules -- Enum.map(templates, & &1.module) do
      [] -> :ok
      missing -> Mix.raise("add an example of #{Enum.map_join(missing, ", ", &inspect/1)} to #{@dir}/examples.exs")
    end
  end

  defp select(templates, []), do: templates

  defp select(templates, names) do
    for name <- names do
      Enum.find(templates, &(name(&1) == name)) ||
        Mix.raise("unknown template #{name}. The templates are: #{Enum.map_join(templates, ", ", &name/1)}")
    end
  end

  # flash_sale for MjmlEEx.Templates.FlashSale
  defp name(%{module: module}), do: module |> Module.split() |> List.last() |> Macro.underscore()

  defp art_job(%{name: name, width: width, height: height} = art, work_dir) do
    %{
      input: Path.expand(Path.join([@dir, "art", "#{name}.html"])),
      width: width,
      height: height,
      transparent: Map.get(art, :transparent, false),
      outputs: [%{path: Path.join([work_dir, "art", "#{name}.png"]), width: width * 2}]
    }
  end

  defp template_job(%{module: module, assigns: assigns} = template, work_dir) do
    name = name(template)
    input = Path.join(work_dir, "#{name}.html")
    File.write!(input, module.to_html(assigns))

    %{
      input: input,
      width: @email_width,
      outputs: [
        # For the gallery
        %{path: Path.join(work_dir, "#{name}.png"), width: @email_width * 2},
        %{path: Path.expand(Path.join(@images_dir, "#{name}.jpg")), width: @image_width, quality: @quality}
      ]
    }
  end

  defp gallery_job(templates, work_dir) do
    input = Path.join(work_dir, "gallery.html")
    width = 2 * 32 + @gallery_columns * 240 + (@gallery_columns - 1) * 20
    File.write!(input, gallery_html(templates, width))

    %{
      input: input,
      width: width,
      outputs: [%{path: Path.expand(Path.join(@images_dir, "gallery.jpg")), width: @gallery_width, quality: @quality}]
    }
  end

  # The top of each template's screenshot, with its label under it
  defp gallery_html(templates, width) do
    tiles =
      Enum.map_join(templates, "\n", fn template ->
        ~s(<div><div class="email"><img src="#{name(template)}.png"></div><p>#{template.label}</p></div>)
      end)

    """
    <html>
    <head>
    <style>
      body { margin: 0; background: #FFFFFF; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
      .gallery { width: #{width}px; padding: 32px; box-sizing: border-box; display: grid; gap: 28px 20px;
                 grid-template-columns: repeat(#{@gallery_columns}, 240px); }
      .email { width: 240px; height: 300px; overflow: hidden; position: relative; box-sizing: border-box;
               border: 1px solid #E4E4E7; border-radius: 12px; background: #F4F4F5;
               box-shadow: 0 1px 2px rgba(0, 0, 0, 0.06), 0 8px 24px rgba(24, 24, 27, 0.08); }
      .email img { width: 238px; display: block; }
      .email:after { content: ""; position: absolute; left: 0; right: 0; bottom: 0; height: 48px;
                     background: linear-gradient(rgba(244, 244, 245, 0), #F4F4F5); }
      p { margin: 10px 0 0; font-size: 15px; font-weight: 600; color: #18181B; text-align: center; }
    </style>
    </head>
    <body><div class="gallery">#{tiles}</div></body>
    </html>
    """
  end
end
