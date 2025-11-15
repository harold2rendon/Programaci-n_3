# lib/trivia/game.ex
defmodule Trivia.Game do
  use GenServer
  require Logger

  # Tiempo por defecto para preguntas (15 segundos)
  @default_time_limit 15
  # Máximo de jugadores por partida
  @max_players 4

  # Estructura del estado del juego
  defstruct [
    :id,
    :topic,
    :creator,
    :players,
    :max_players,
    :total_questions,
    :time_limit,
    :status,
    :current_question,
    :current_question_index,
    :current_correct_answer,
    :answers_received,
    :scores,
    :start_time,
    :timer_ref
  ]

  # API pública
  def start_link(game_params) do
    GenServer.start_link(__MODULE__, game_params)
  end

  # Crear una nueva partida
  def create_game(
        topic,
        total_questions,
        time_limit \\ @default_time_limit,
        max_players \\ @max_players
      ) do
    Trivia.GameSupervisor.create_game(topic, total_questions, time_limit, max_players)
  end

  # Unirse a una partida
  def join_game(game_pid, username) do
    GenServer.call(game_pid, {:join, username})
  end

  # Iniciar una partida
  def start_game(game_pid, username) do
    GenServer.call(game_pid, {:start, username})
  end

  # Responder a una pregunta
  def answer_question(game_pid, username, question_index, answer) do
    GenServer.call(game_pid, {:answer, username, question_index, answer})
  end

  # Obtener el estado de la partida
  def get_game_state(game_pid) do
    GenServer.call(game_pid, :get_state)
  end

  # Listar jugadores en la partida
  def list_players(game_pid) do
    GenServer.call(game_pid, :list_players)
  end

  # Inicialización del GenServer
  def init(params) do
    game_id = params.id

    state = %__MODULE__{
      id: game_id,
      topic: params.topic,
      creator: nil,
      players: %{},
      max_players: params.max_players,
      total_questions: params.total_questions,
      time_limit: params.time_limit,
      status: :waiting,
      current_question: nil,
      current_question_index: 0,
      answers_received: %{},
      scores: %{},
      start_time: nil,
      timer_ref: nil
    }

    Logger.info("Nueva partida creada: #{game_id} - Tema: #{params.topic}")
    {:ok, state}
  end

  # Manejo de llamadas
  def handle_call({:join, username}, _from, state) do
    cond do
      state.status != :waiting ->
        {:reply, {:error, "La partida ya ha comenzado"}, state}

      map_size(state.players) >= state.max_players ->
        {:reply, {:error, "La partida está llena"}, state}

      Map.has_key?(state.players, username) ->
        {:reply, {:error, "Ya estás en esta partida"}, state}

      true ->
        creator = if map_size(state.players) == 0, do: username, else: state.creator

        new_player = %{
          username: username,
          score: 0,
          connected: true
        }

        updated_players = Map.put(state.players, username, new_player)
        updated_scores = Map.put(state.scores, username, 0)

        new_state = %{state | players: updated_players, scores: updated_scores, creator: creator}

        broadcast_to_players(new_state, "#{username} se unió a la partida")
        Logger.info("#{username} se unió a la partida #{state.id}")

        {:reply, {:ok, new_state}, new_state}
    end
  end

  def handle_call({:start, username}, _from, state) do
    cond do
      state.creator != username ->
        {:reply, {:error, "Solo el creador puede iniciar la partida"}, state}

      state.status != :waiting ->
        {:reply, {:error, "La partida ya ha comenzado"}, state}

      map_size(state.players) < 1 ->
        {:reply, {:error, "Se necesitan al menos 2 jugadores"}, state}

      true ->
        questions = Trivia.QuestionBank.get_questions_by_category(state.topic)

        if Enum.empty?(questions) do
          {:reply, {:error, "No hay preguntas disponibles para el tema #{state.topic}"}, state}
        else
          selected_questions = Enum.take(questions, state.total_questions)

          if length(selected_questions) < state.total_questions do
            Logger.warning(
              "Solo hay #{length(selected_questions)} preguntas para el tema #{state.topic}"
            )
          end

          first_question = Enum.at(selected_questions, 0)

          new_state = %{
            state
            | status: :playing,
              current_question: first_question,
              current_question_index: 1,
              current_correct_answer: first_question.correct_answer,
              start_time: System.system_time(:second),
              answers_received: %{}
          }

          timer_ref = Process.send_after(self(), :question_timeout, state.time_limit * 1000)
          new_state = %{new_state | timer_ref: timer_ref}

          broadcast_question(new_state)

          Logger.info("Partida #{state.id} iniciada por #{username}")
          {:reply, {:ok, new_state}, new_state}
        end
    end
  end

  def handle_call({:answer, username, question_index, answer}, _from, state) do
    cond do
      state.status != :playing ->
        {:reply, {:error, "La partida no está en juego"}, state}

      question_index != state.current_question_index ->
        {:reply, {:error, "Pregunta incorrecta"}, state}

      not Map.has_key?(state.players, username) ->
        {:reply, {:error, "No estás en esta partida"}, state}

      Map.has_key?(state.answers_received, username) ->
        {:reply, {:error, "Ya respondiste esta pregunta"}, state}

      true ->
        is_correct = String.upcase(answer) == String.upcase(state.current_correct_answer)
        score_change = if is_correct, do: 10, else: -5

        current_score = Map.get(state.scores, username, 0)
        new_score = current_score + score_change

        updated_scores = Map.put(state.scores, username, new_score)
        updated_answers = Map.put(state.answers_received, username, {answer, is_correct})

        updated_player = Map.get(state.players, username) |> Map.put(:score, new_score)
        updated_players = Map.put(state.players, username, updated_player)

        new_state = %{
          state
          | scores: updated_scores,
            answers_received: updated_answers,
            players: updated_players
        }

        message =
          if is_correct do
            "#{username} respondió correctamente: +10 puntos"
          else
            "#{username} respondió incorrectamente: -5 puntos"
          end

        broadcast_to_players(new_state, message)

        if map_size(new_state.answers_received) == map_size(new_state.players) do
          Process.cancel_timer(new_state.timer_ref)
          Process.send_after(self(), :next_question, 2000)
        end

        {:reply, {:ok, %{correct: is_correct, score: new_score, score_change: score_change}},
         new_state}
    end
  end

  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_call(:list_players, _from, state) do
    player_list =
      state.players
      |> Map.values()
      |> Enum.sort_by(& &1.score, :desc)

    {:reply, {:ok, player_list}, state}
  end

  def handle_info(:question_timeout, state) do
    if state.status == :playing do
      broadcast_to_players(
        state,
        "Tiempo agotado! Respuesta correcta: #{state.current_correct_answer}"
      )

      updated_players = penalize_non_responders(state.players, state.answers_received)

      new_state = %{state | players: updated_players}

      Process.send_after(self(), :next_question, 3000)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_info(:next_question, state) do
    if state.current_question_index >= state.total_questions do
      # Fin del juego
      end_game(state)
    else
      questions = Trivia.QuestionBank.get_questions_by_category(state.topic)

      if length(questions) >= state.current_question_index do
        next_question = Enum.at(questions, state.current_question_index)

        new_state = %{
          state
          | current_question: next_question,
            current_question_index: state.current_question_index + 1,
            current_correct_answer: next_question.correct_answer,
            answers_received: %{},
            start_time: System.system_time(:second)
        }

        timer_ref = Process.send_after(self(), :question_timeout, state.time_limit * 1000)
        new_state = %{new_state | timer_ref: timer_ref}

        broadcast_question(new_state)

        {:noreply, new_state}
      else
        end_game(state)
      end
    end
  end

  def handle_info(:shutdown, state) do
    Logger.info("Cerrando partida #{state.id}")
    {:stop, :normal, state}
  end

  def terminate(reason, state) do
    Logger.info("Partida #{state.id} terminada: #{inspect(reason)}")
    :ok
  end

  # Funciones privadas

  # Generar un ID único para la partida
  defp generate_game_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode64()
    |> String.replace(~r/[+\/=]/, "")
    |> String.slice(0, 8)
  end

  # Enviar mensaje a todos los jugadores
  defp broadcast_to_players(state, message) do
    IO.puts("\n=== MENSAJE DE PARTIDA #{state.id} ===")
    IO.puts(message)
    IO.puts("=================================\n")
  end

  # Enviar la pregunta actual a todos los jugadores
  defp broadcast_question(state) do
    question = state.current_question

    question_header = """

    PREGUNTA #{state.current_question_index}/#{state.total_questions}
    Tema: #{question.category}

    #{question.question}

    """

    options_text =
      Enum.with_index(question.all_answers, 1)
      |> Enum.map(fn {answer, index} -> "#{index}. #{answer}" end)
      |> Enum.join("\n")

    time_text = "\n\nTienes #{state.time_limit} segundos para responder\n"

    full_question_text = question_header <> options_text <> time_text
    broadcast_to_players(state, full_question_text)
  end

  # Penalizar a los jugadores que no respondieron
  defp penalize_non_responders(players, answers_received) do
    Map.new(players, fn {username, player} ->
      if not Map.has_key?(answers_received, username) do
        new_score = player.score - 2
        IO.puts("#{username} no respondió: -2 puntos")
        {username, %{player | score: new_score}}
      else
        {username, player}
      end
    end)
  end

  # Terminar la partida y mostrar resultados
  defp end_game(state) do
    ranking =
      state.players
      |> Map.values()
      |> Enum.sort_by(& &1.score, :desc)

    results_header = """

    PARTIDA TERMINADA - #{state.topic}
    ================================
    """

    ranking_text =
      Enum.with_index(ranking, 1)
      |> Enum.map(fn {player, index} ->
        medal =
          case index do
            1 -> "1"
            2 -> "2"
            3 -> "3"
            _ -> "#{index}."
          end

        "#{medal} #{player.username}: #{player.score} puntos"
      end)
      |> Enum.join("\n")

    winner_text = "\n\nGanador: #{hd(ranking).username}"

    full_results_text = results_header <> ranking_text <> winner_text
    broadcast_to_players(state, full_results_text)

    save_game_results(state, ranking)

    update_global_scores(ranking, state.topic)

    Process.send_after(self(), :shutdown, 5000)

    {:noreply, %{state | status: :finished}}
  end

  # Guardar resultados de la partida en un archivo
  defp save_game_results(state, ranking) do
    results = """
    Fecha: #{DateTime.utc_now()}
    Partida: #{state.id}
    Tema: #{state.topic}
    Jugadores: #{map_size(state.players)}
    Ganador: #{hd(ranking).username} con #{hd(ranking).score} puntos
    Puntajes: #{inspect(Enum.map(ranking, fn p -> {p.username, p.score} end))}
    =================================
    """

    File.write!("data/results.log", results, [:append])
    Logger.info("Resultados guardados para partida #{state.id}")
  end

  # Actualizar puntajes globales de los usuarios
  defp update_global_scores(ranking, topic) do
    Enum.each(ranking, fn player ->
      Trivia.UserManager.update_user_score(player.username, player.score, topic)
    end)
  end
end
