defmodule Trivia.IndividualGame do
  use GenServer
  require Logger

  # Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Función para iniciar un juego estándar
  def start_game(session_id) do
    GenServer.call(__MODULE__, {:start_game, session_id})
  end

  # Función para iniciar un juego con configuración personalizada
  def start_game_with_settings(session_id, category, num_questions, time_limit) do
    GenServer.call(
      __MODULE__,
      {:start_game_with_settings, session_id, category, num_questions, time_limit}
    )
  end

  # Callback de terminación
  def terminate(_reason, _state) do
    :ok
  end

  # Función para responder una pregunta
  def answer_question(session_id, answer, time_taken) do
    GenServer.call(__MODULE__, {:answer_question, session_id, answer, time_taken})
  end

  # Función para obtener el estado actual del juego
  def get_game_state(session_id) do
    GenServer.call(__MODULE__, {:get_game_state, session_id})
  end

  # Server callbacks
  def init(state) do
    {:ok, state}
  end

  # Manejo de llamadas
  def handle_call({:start_game, session_id}, _from, state) do
    # Tu implementación existente
    case Map.get(state, session_id) do
      nil ->
        game_state = %{
          session_id: session_id,
          score: 0,
          questions_answered: 0,
          max_questions: 5,
          current_question: nil,
          time_limit: 0,
          user: nil,
          status: :playing
        }

        categories = Trivia.QuestionBank.get_categories()
        random_category = Enum.random(categories)
        questions = Trivia.QuestionBank.get_questions_by_category(random_category)

        if Enum.empty?(questions) do
          {:reply, {:error, "No hay preguntas disponibles"}, state}
        else
          first_question = Enum.random(questions)

          case Trivia.UserManager.get_user_by_session(session_id) do
            {:ok, user} ->
              game_state = %{game_state | current_question: first_question, user: user}

              updated_state = Map.put(state, session_id, game_state)
              {:reply, {:ok, game_state}, updated_state}

            {:error, _} ->
              {:reply, {:error, "Usuario no encontrado"}, state}
          end
        end

      _game_state ->
        {:reply, {:error, "Ya tienes un juego en curso"}, state}
    end
  end

  def handle_call(
        {:start_game_with_settings, session_id, category, max_questions, time_limit},
        _from,
        state
      ) do
    case Map.get(state, session_id) do
      nil ->
        game_state = %{
          session_id: session_id,
          score: 0,
          questions_answered: 0,
          max_questions: max_questions,
          current_question: nil,
          time_limit: time_limit,
          user: nil,
          status: :playing
        }

        questions =
          if category do
            Trivia.QuestionBank.get_questions_by_category(category)
          else
            Trivia.QuestionBank.get_categories()
            |> Enum.flat_map(&Trivia.QuestionBank.get_questions_by_category/1)
          end

        if Enum.empty?(questions) do
          {:reply, {:error, "No hay preguntas disponibles"}, state}
        else
          selected_questions = Enum.take(Enum.shuffle(questions), max_questions)
          first_question = List.first(selected_questions)

          case Trivia.UserManager.get_user_by_session(session_id) do
            {:ok, user} ->
              game_state = %{game_state | current_question: first_question, user: user}

              updated_state = Map.put(state, session_id, game_state)
              {:reply, {:ok, game_state}, updated_state}

            {:error, _} ->
              {:reply, {:error, "Usuario no encontrado"}, state}
          end
        end

      _game_state ->
        {:reply, {:error, "Ya tienes un juego en curso"}, state}
    end
  end

  def handle_call({:answer_question, session_id, answer, time_taken}, _from, state) do
    case Map.get(state, session_id) do
      nil ->
        {:reply, {:error, "No hay juego activo"}, state}

      game_state ->
        question = game_state.current_question
        is_correct = String.upcase(answer) == String.upcase(question.correct_answer)

        points = if is_correct, do: 10, else: 0
        new_score = game_state.score + points

        updated_game_state = %{
          game_state
          | score: new_score,
            questions_answered: game_state.questions_answered + 1
        }

        if updated_game_state.questions_answered >= updated_game_state.max_questions do
          final_state = %{updated_game_state | status: :finished}
          update_user_stats(session_id, final_state.score)

          updated_state = Map.delete(state, session_id)
          {:reply, {:ok, :game_over, final_state}, updated_state}
        else
          categories = Trivia.QuestionBank.get_categories()
          random_category = Enum.random(categories)
          questions = Trivia.QuestionBank.get_questions_by_category(random_category)

          if Enum.empty?(questions) do
            {:reply, {:error, "No hay más preguntas disponibles"}, state}
          else
            next_question = Enum.random(questions)
            updated_game_state = %{updated_game_state | current_question: next_question}

            updated_state = Map.put(state, session_id, updated_game_state)
            {:reply, {:ok, :continue, updated_game_state}, updated_state}
          end
        end
    end
  end

  def handle_call({:get_game_state, session_id}, _from, state) do
    case Map.get(state, session_id) do
      nil ->
        {:reply, {:error, "No hay juego activo"}, state}

      game_state ->
        {:reply, {:ok, game_state}, state}
    end
  end

  # Funciones privadas

  # Cálculo de puntos basado en la respuesta y el tiempo tomado
  defp calculate_points(is_correct, _time_taken, _time_limit) do
    if is_correct, do: 10, else: 0
  end

  # Actualización de estadísticas del usuario al finalizar el juego
  defp update_user_stats(session_id, score) do
    case Trivia.UserManager.get_user_by_session(session_id) do
      {:ok, user} ->
        Trivia.UserManager.update_user_score(user.username, score, "individual")

      _ ->
        :ok
    end
  end
end
