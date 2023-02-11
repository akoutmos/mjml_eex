defmodule MjmlEEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :mjml_eex,
      version: "0.9.0",
      elixir: ">= 1.11.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "MJML EEx",
      source_url: "https://github.com/akoutmos/mjml_eex",
      homepage_url: "https://hex.pm/packages/mjml_eex",
      description: "Create emails that WOW your customers using MJML and EEx",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ],
      package: package(),
      deps: deps(),
      docs: docs(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/test_components", "test/test_layouts"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      name: "mjml_eex",
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md),
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
      source_ref: "master",
      logo: "guides/images/logo.svg",
      extras: ["README.md"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Production deps
      {:mjml, "~> 1.3.2"},
      {:phoenix_html, "~> 3.2"},
      {:telemetry, "~> 1.0"},
      {:erlexec, "~> 2.0", optional: true},

      # Development deps
      {:ex_doc, "~> 0.28.4", only: :dev},
      {:excoveralls, "~> 0.14.4", only: [:test, :dev], runtime: false},
      {:doctor, "~> 0.18.0", only: :dev},
      {:credo, "~> 1.6.1", only: :dev},
      {:git_hooks, "~> 0.7.3", only: [:test, :dev], runtime: false}
    ]
  end

  defp aliases do
    [
      docs: ["docs", &copy_files/1]
    ]
  end

  defp copy_files(_) do
    # Set up directory structure
    File.mkdir_p!("./doc/guides/images")

    # Copy over image files
    "./guides/images/"
    |> File.ls!()
    |> Enum.each(fn image_file ->
      File.cp!("./guides/images/#{image_file}", "./doc/guides/images/#{image_file}")
    end)
  end
end
