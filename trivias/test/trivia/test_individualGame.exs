# test/trivia/individual_game_test.exs
defmodule Trivia.IndividualGameTest do
  use ExUnit.Case
  alias Trivia.IndividualGame

  setup do
    {:ok, pid} = GenServer.start_link(IndividualGame, %{}, name: IndividualGame)
    {:ok, pid: pid}
  end

  test "start_game/1 creates new individual game" do
    session_id = "test_session_001"
    assert {:ok, game_state} = IndividualGame.start_game(session_id)
    assert game_state.session_id == session_id
    assert game_state.score == 0
    assert game_state.questions_answered == 0
    assert game_state.status == :playing
    assert game_state.current_question != nil
  end

  test "start_game_with_settings/4 creates custom game" do
    session_id = "custom_session"
    assert {:ok, game_state} = IndividualGame.start_game_with_settings(session_id, "Science", 7, 25)
    assert game_state.max_questions == 7
    assert game_state.time_limit == 25
    assert game_state.current_question != nil
  end

  test "start_game/1 prevents multiple active games" do
    session_id = "single_session"
    IndividualGame.start_game(session_id)
    assert {:error, "Ya tienes un juego en curso"} = IndividualGame.start_game(session_id)
  end

  test "get_game_state/1 returns game state" do
    session_id = "state_check"
    IndividualGame.start_game(session_id)
    assert {:ok, state} = IndividualGame.get_game_state(session_id)
    assert state.session_id == session_id
  end

  test "get_game_state/1 fails for non-existent game" do
    assert {:error, "No hay juego activo"} = IndividualGame.get_game_state("nonexistent")
  end

  test "answer_question/3 processes correct and incorrect answers" do
    session_id = "answer_test"
    IndividualGame.start_game(session_id)

    # Get current question to test answer
    {:ok, state} = IndividualGame.get_game_state(session_id)
    correct_answer = state.current_question.correct_answer
    wrong_answer = "WrongAnswer123"

    # Test correct answer
    assert {:ok, :continue, new_state} =
            IndividualGame.answer_question(session_id, correct_answer, 5)
    assert new_state.score > 0
    assert new_state.questions_answered == 1

    # Test wrong answer
    assert {:ok, :continue, final_state} =
            IndividualGame.answer_question(session_id, wrong_answer, 3)
    # Score should remain the same or decrease based on implementation
    assert final_state.questions_answered == 2
  end
end
