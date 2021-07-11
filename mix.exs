defmodule PhoenixLiveViewExt.MixProject do
  use Mix.Project

  @version "1.2.1"

  def project do
    [
      app: :phoenix_live_view_ext,
      version: @version,
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      { :dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      { :phoenix, "~> 1.5"},
      { :phoenix_live_view, "~> 0.15.4"},
      { :ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end

  defp description() do
    """
    A library of functional extensions for the Phoenix LiveView framework.
    """
  end

  defp package() do
    [
      maintainers: ["DaTrader"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/DaTrader/phoenix_live_view_ext"},
      files: ~w(assets/js lib .formatter.exs mix.exs README.md LICENSE.md CHANGELOG.md)
    ]
  end

  defp docs() do
    [
      main: "readme",
      name: "PhoenixLiveViewExt",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/phoenix_live_view_ext",
      source_url: "https://github.com/DaTrader/phoenix_live_view_ext",
      extras: [
        "README.md"
      ]
    ]
  end
end
