# test/trivia/game_supervisor_test.exs
defmodule Trivia.GameSupervisorTest do
  use ExUnit.Case
  alias Trivia.GameSupervisor

  setup do
    {:ok, pid} = GameSupervisor.start_link([])
    {:ok, pid: pid}
  end

  test "start_link/1 initializes supervisor" do
    assert Process.alive?(Process.whereis(Trivia.GameSupervisor))
  end

  test "create_game/4 creates game with valid parameters" do
    assert {:ok, game_pid, game_id} = GameSupervisor.create_game("Science", 10)
    assert is_pid(game_pid)
    assert is_binary(game_id)
    assert Process.alive?(game_pid)
  end

  test "create_game/4 uses default parameters correctly" do
    assert {:ok, _game_pid, _game_id} = GameSupervisor.create_game("History", 5)
    assert {:ok, _game_pid, _game_id} = GameSupervisor.create_game("Geography", 8, 20)
    assert {:ok, _game_pid, _game_id} = GameSupervisor.create_game("Art", 12, 15, 3)
  end

  test "list_games/0 returns created games" do
    {:ok, _pid, game_id} = GameSupervisor.create_game("TestTopic", 5, 10, 2)

    games = GameSupervisor.list_games()
    assert is_list(games)

    game = Enum.find(games, fn g -> g.id == game_id end)
    if game do
      assert game.topic == "TestTopic"
      assert game.total_questions == 5
    end
  end

  test "generate_game_id/0 creates unique IDs" do
    id1 = :sys.get_state(Trivia.GameSupervisor) |> Map.get(:game_counter)
    {:ok, _pid, game_id1} = GameSupervisor.create_game("Topic1", 5)
    {:ok, _pid, game_id2} = GameSupervisor.create_game("Topic2", 5)

    assert game_id1 != game_id2
    assert String.length(game_id1) >= 8
    assert String.length(game_id2) >= 8
  end
end
