# test/trivia/question_bank_test.exs
defmodule Trivia.QuestionBankTest do
  use ExUnit.Case
  alias Trivia.QuestionBank

  setup do
    {:ok, pid} = GenServer.start_link(QuestionBank, %{}, name: QuestionBank)
    {:ok, pid: pid}
  end

  test "get_categories/0 returns non-empty list" do
    categories = QuestionBank.get_categories()
    assert is_list(categories)
    assert length(categories) > 0
    assert Enum.all?(categories, &is_binary/1)
  end

  test "get_question/0 returns valid question structure" do
    assert {:ok, question} = QuestionBank.get_question()
    assert_valid_question(question)
  end

  test "get_question_by_category/1 returns category-specific question" do
    categories = QuestionBank.get_categories()
    category = hd(categories)
    assert {:ok, question} = QuestionBank.get_question_by_category(category)
    assert question.category == category
    assert_valid_question(question)
  end

  test "get_question_by_category/1 fails for invalid category" do
    assert {:error, error_msg} = QuestionBank.get_question_by_category("InvalidCategory123")
    assert String.contains?(error_msg, "No hay preguntas disponibles")
  end

  test "get_questions_by_category/2 returns list of questions" do
    categories = QuestionBank.get_categories()
    category = hd(categories)
    questions = QuestionBank.get_questions_by_category(category, 2)
    assert is_list(questions)
    assert Enum.all?(questions, &(&1.category == category))
  end

  test "questions have valid answer structure" do
    {:ok, question} = QuestionBank.get_question()
    assert length(question.all_answers) == 4
    assert question.correct_answer in question.all_answers
    assert String.length(question.question) > 10
    assert String.length(question.correct_answer) > 0
  end

  defp assert_valid_question(question) do
    assert Map.has_key?(question, :category)
    assert Map.has_key?(question, :question)
    assert Map.has_key?(question, :correct_answer)
    assert Map.has_key?(question, :all_answers)
    assert is_binary(question.category)
    assert is_binary(question.question)
    assert is_binary(question.correct_answer)
    assert is_list(question.all_answers)
  end
end
