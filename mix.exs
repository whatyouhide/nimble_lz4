defmodule NimbleLz4.MixProject do
  use Mix.Project

  def project do
    [
      app: :nimble_lz4,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      deps: deps(),
      rustler_crates: [
        nimblelz4: [mode: rustler_mode(Mix.env())]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp rustler_mode(:prod), do: :release
  defp rustler_mode(_env), do: :debug

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler, "~> 0.25.0"},

      # Dev and test dependencies
      {:benchee, "~> 1.1", only: :dev},
      {:stream_data, "~> 0.5.0", only: :test}
    ]
  end
end
