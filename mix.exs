defmodule NimbleLz4.MixProject do
  use Mix.Project

  @version "0.2.0-dev"
  @source_url "https://github.com/whatyouhide/nimble_lz4"

  def project do
    [
      app: :nimble_lz4,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      deps: deps(),

      # Rustler
      rustler_crates: [
        nimblelz4: [mode: rustler_mode(Mix.env())]
      ],

      # Hex
      package: package(),
      description: "NIF-based LZ4 compression and decompression support for Elixir.",

      # Docs
      name: "NimbleLZ4",
      docs: [
        main: "NimbleLZ4",
        source_ref: "v#{@version}",
        source_url: @source_url
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: []
    ]
  end

  defp package do
    [
      files: [
        "lib",
        "native",
        "checksum-*.exs",
        "mix.exs"
      ],
      licenses: ["Apache-2.0"],
      maintainers: ["Andrea Leopardi"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp rustler_mode(:prod), do: :release
  defp rustler_mode(_env), do: :debug

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler, "~> 0.25.0"},
      {:rustler_precompiled, "~> 0.5.0"},

      # Dev and test dependencies
      {:benchee, "~> 1.1", only: :dev},
      {:ex_doc, "~> 0.28", only: :dev},
      {:stream_data, "~> 0.5.0", only: :test}
    ]
  end
end
