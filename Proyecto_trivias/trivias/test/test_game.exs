# test/trivia/game_test.exs
defmodule Trivia.GameTest do
  use ExUnit.Case
  alias Trivia.Game

  setup do
    game_params = %{
      id: "TEST123",
      topic: "Science",
      total_questions: 3,
      time_limit: 5,
      max_players: 2
    }

    {:ok, pid} = Game.start_link(game_params)
    {:ok, game_pid: pid, params: game_params}
  end

  test "init/1 initializes game state correctly", %{params: params} do
    {:ok, state} = Game.get_game_state(self())
    assert state.id == params.id
    assert state.topic == params.topic
    assert state.status == :waiting
    assert state.players == %{}
    assert state.max_players == params.max_players
  end

  test "join_game/2 allows players to join", %{game_pid: game_pid} do
    assert {:ok, state} = Game.join_game(game_pid, "player1")
    assert {:ok, state} = Game.join_game(game_pid, "player2")
    assert map_size(state.players) == 2
  end

  test "join_game/2 prevents exceeding max players", %{game_pid: game_pid} do
    Game.join_game(game_pid, "player1")
    Game.join_game(game_pid, "player2")
    assert {:error, "La partida está llena"} = Game.join_game(game_pid, "player3")
  end

  test "join_game/2 prevents duplicate players", %{game_pid: game_pid} do
    Game.join_game(game_pid, "player1")
    assert {:error, "Ya estás en esta partida"} = Game.join_game(game_pid, "player1")
  end

  test "list_players/1 returns player list", %{game_pid: game_pid} do
    Game.join_game(game_pid, "player1")
    Game.join_game(game_pid, "player2")

    assert {:ok, players} = Game.list_players(game_pid)
    assert length(players) == 2
    assert Enum.any?(players, &(&1.username == "player1"))
    assert Enum.any?(players, &(&1.username == "player2"))
  end

  test "get_game_state/1 returns current state", %{game_pid: game_pid, params: params} do
    assert {:ok, state} = Game.get_game_state(game_pid)
    assert state.id == params.id
    assert state.topic == params.topic
  end
end
