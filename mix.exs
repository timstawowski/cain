defmodule Cain.MixProject do
  use Mix.Project

  def project do
    [
      app: :cain,
      version: "0.3.8",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      deps: deps(),
      name: "Cain",
      source_url: "https://github.com/timstawowski/cain"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "dev"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      mod: {Cain, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:tesla, "~> 1.3.1"},
      {:jason, ">= 1.0.0"},
      {:beauty_exml, "~> 0.1.0"},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Camunda-REST-API-Interpreter"
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/timstawowski/cain"}
    ]
  end
end
