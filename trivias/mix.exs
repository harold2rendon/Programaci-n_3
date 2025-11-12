defmodule Trivia.MixProject do
  use Mix.Project

  def project do
    [
      app: :trivia,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Trivia.Application, []}
    ]
  end

  defp deps do
    [
      {:pbkdf2_elixir, "~> 2.0"}
    ]
  end
end
