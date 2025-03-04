defmodule Youtex.MixProject do
  use Mix.Project

  @version "0.3.0"

  def project do
    [
      app: :youtex,
      version: @version,
      name: "Youtex",
      description: "A tool to list or to retrieve video transcriptions from Youtube",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      dialyzer: [
        plt_add_deps: :apps_direct,
        plt_add_apps: [],
        plt_ignore_apps: [:logger]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :poison, :httpoison, :typed_struct, :elixir_xml_to_map]
    ]
  end

  defp deps do
    [
      {:elixir_xml_to_map, "~> 2.0"},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false},
      {:poison, "~> 6.0"},
      {:httpoison, "~> 2.2"},
      {:typed_struct, "~> 0.3"},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/patrykwozinski/youtex"}
    ]
  end
end
