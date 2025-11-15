# lib/trivia/application.ex
defmodule Trivia.Application do
  use Application

  def start(_type, _args) do
    children = [
      # DynamicSupervisor para clientes
      {DynamicSupervisor, strategy: :one_for_one, name: Trivia.ClientSupervisor},
      # GameSupervisor para partidas multijugador
      Trivia.GameSupervisor,
      # UserManager
      Trivia.UserManager,
      # QuestionBank
      Trivia.QuestionBank,
      # IndividualGame para juegos individuales
      Trivia.IndividualGame,
      # Server principal
      {Trivia.Server, 4040}
    ]

    opts = [strategy: :one_for_one, name: Trivia.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
