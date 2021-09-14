defmodule MjmlEEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :mjml_eex,
      version: "0.1.0",
      elixir: ">= 1.11.0",
      name: "MJML EEx",
      source_url: "https://github.com/akoutmos/mjml_eex",
      homepage_url: "https://hex.pm/packages/mjml_eex",
      description: "A wrapper around https://hex.pm/packages/mjml to easily use MJML with EEx",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      name: "mjml_eex",
      files: ~w(lib mix.exs README.md),
      licenses: ["MIT"],
      maintainers: ["Alex Koutmos"],
      links: %{
        "GitHub" => "https://github.com/akoutmos/mjml_eex",
        "Sponsor" => "https://github.com/sponsors/akoutmos"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mjml, "~> 1.1.1"}
    ]
  end
end
