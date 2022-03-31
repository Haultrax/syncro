defmodule Syncro.MixProject do
  use Mix.Project

  def project do
    [
      app: :syncro,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Syncro.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix_pubsub, "~> 2.0"},
      {:liaison, "~> 0.1"}
    ]
  end
end
