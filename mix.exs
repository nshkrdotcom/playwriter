defmodule Playwriter.MixProject do
  use Mix.Project

  def project do
    [
      app: :playwriter,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: Playwriter.CLI]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:playwright, "~> 1.49.1-alpha.2"}
    ]
  end
end
