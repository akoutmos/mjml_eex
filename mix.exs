defmodule MjmlEEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :mjml_eex,
      version: project_version(),
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "MJML EEx",
      source_url: "https://github.com/akoutmos/mjml_eex",
      homepage_url: "https://hex.pm/packages/mjml_eex",
      description: "Create emails that WOW your customers using MJML and EEx",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      package: package(),
      deps: deps(),
      docs: docs(),
      dialyzer: dialyzer(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "spec_gen/mix", "screenshots/mix"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      name: "mjml_eex",
      # .formatter.exs exports the formatter settings for `import_deps: [:mjml_eex]`. hex.pm
      # shows the README from the package, so the images it references are packaged too.
      files:
        ~w(lib images guides/images/logo.svg guides/images/templates/gallery.jpg) ++
          ~w(mix.exs .formatter.exs README.md LICENSE CHANGELOG.md VERSION),
      licenses: ["MIT"],
      maintainers: ["Alex Koutmos"],
      links: %{
        "GitHub" => "https://github.com/akoutmos/mjml_eex",
        "Sponsor" => "https://github.com/sponsors/akoutmos"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      # Releases are tagged with their version, such as 1.0.0-rc.1
      source_ref: project_version(),
      logo: "guides/images/logo.svg",
      # Guides reference their images as images/..., which works on GitHub and in the docs
      assets: %{"guides/images" => "images"},
      extras: [
        "README.md",
        "guides/getting_started.md",
        "guides/templates.md",
        "guides/components.md",
        "guides/core_components.md",
        "guides/prebuilt_templates.md",
        "guides/layouts.md",
        "guides/includes.md",
        "guides/validation.md",
        "guides/formatting.md",
        "guides/testing.md",
        "guides/configuration.md",
        "guides/telemetry.md",
        "guides/migrating_from_0x.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Guides: ~r{guides/(?!migrating)},
        Upgrading: ["guides/migrating_from_0x.md", "CHANGELOG.md"]
      ],
      groups_for_modules: [
        Templates: [MjmlEEx, MjmlEEx.Component, MjmlEEx.Rendered],
        "Core components": [MjmlEEx.CoreComponents, MjmlEEx.Theme],
        "Prebuilt templates": [
          MjmlEEx.Templates.Welcome,
          MjmlEEx.Templates.VerifyEmail,
          MjmlEEx.Templates.MagicLink,
          MjmlEEx.Templates.OneTimePassword,
          MjmlEEx.Templates.ForgotPassword,
          MjmlEEx.Templates.TeamInvitation,
          MjmlEEx.Templates.SecurityAlert,
          MjmlEEx.Templates.TrialConversion,
          MjmlEEx.Templates.PaymentFailed,
          MjmlEEx.Templates.Invoice,
          MjmlEEx.Templates.OrderConfirmation,
          MjmlEEx.Templates.Webinar,
          MjmlEEx.Templates.Newsletter,
          MjmlEEx.Templates.ProductLaunch,
          MjmlEEx.Templates.FlashSale
        ],
        Errors: [MjmlEEx.ParseError, MjmlEEx.ValidationError, MjmlEEx.CompileError],
        Formatting: [MjmlEEx.Formatter, MjmlEEx.Formatter.TagFormatter],
        Compilers: [MjmlEEx.Compiler, MjmlEEx.Compilers.Rust],
        Telemetry: [MjmlEEx.Telemetry]
      ],
      # The spec and screenshot generators are dev-only tasks for maintainers, and aren't part
      # of the package
      filter_modules: fn module, _metadata ->
        module not in [Mix.Tasks.MjmlEex.Gen.Spec, Mix.Tasks.MjmlEex.Gen.Screenshots]
      end
    ]
  end

  defp dialyzer do
    [
      # The formatter plugin and the spec generator task use Mix
      plt_add_apps: [:mix],
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Production deps
      {:mjml, "~> 6.0"},
      {:phoenix_html, "~> 4.0"},
      {:telemetry, "~> 1.0"},

      # Development deps
      {:gettext, "~> 1.0", only: :test},
      {:stream_data, "~> 1.1", only: :test},
      {:ex_doc, "~> 0.40", only: :dev},
      {:excoveralls, "~> 0.18", only: [:test, :dev], runtime: false},
      {:doctor, "~> 0.23", only: :dev},
      {:credo, "~> 1.7", only: :dev},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      docs: ["docs", &copy_files/1]
    ]
  end

  defp project_version do
    "VERSION"
    |> File.read!()
    |> String.trim()
  end

  # The README references its images as guides/images/...
  defp copy_files(_) do
    File.mkdir_p!("./doc/guides")
    File.mkdir_p!("./doc/images")

    File.cp_r!("./guides/images", "./doc/guides/images")
    File.cp_r!("./images", "./doc/images")

    # Both this copy and ExDoc's copy of the assets include the .DS_Store files Finder makes
    for path <- Path.wildcard("./doc/**/.DS_Store", match_dot: true) do
      File.rm!(path)
    end
  end
end
