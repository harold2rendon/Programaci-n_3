defmodule Trivia.CLI do
  import IO, only: [gets: 1, puts: 1]
  import String, only: [trim: 1]

  def main(_args) do
    puts("=== Bienvenido al Juego de Trivia ===")
    show_main_menu()
  end

  defp show_main_menu do
    puts("\n1. Registrarse")
    puts("2. Iniciar sesión")
    puts("3. Ver leaderboard")
    puts("4. Ver categorías disponibles")
    puts("5. Salir")

    case gets("Selecciona una opción: ") |> trim() do
      "1" ->
        register_user()

      "2" ->
        login_user()

      "3" ->
        show_leaderboard()

      "4" ->
        show_categories()

      "5" ->
        puts("¡Hasta luego!")

      _ ->
        puts("Opción inválida")
        show_main_menu()
    end
  end

  defp show_game_menu(session_id, user) do
    puts("\n=== Menú del Juego ===")
    puts("1. Jugar trivia rápida (5 preguntas, 30 segundos)")
    puts("2. Jugar trivia estándar (10 preguntas, sin límite de tiempo)")
    puts("3. Jugar trivia personalizada")
    puts("4. Jugar por categoría específica")
    puts("5. Modo Multijugador")
    puts("6. Ver mi puntuación")
    puts("7. Clasificación general")
    puts("8. Cerrar sesión")

    case gets("Selecciona una opción: ") |> trim() do
      "1" ->
        start_quick_game(session_id, user)

      "2" ->
        start_standard_game(session_id, user)

      "3" ->
        start_custom_game(session_id, user)

      "4" ->
        start_game_by_category(session_id, user)

      "5" ->
        show_multiplayer_menu(session_id, user)

      "6" ->
        show_my_score(user, session_id)

      "7" ->
        show_leaderboard()

      "8" ->
        Trivia.UserManager.logout_user(session_id)
        puts("Sesión cerrada")
        show_main_menu()

      _ ->
        puts("Opción inválida")
        show_game_menu(session_id, user)
    end
  end

  defp show_multiplayer_menu(session_id, user) do
    puts("\n=== Modo Multijugador ===")
    puts("1. Crear una partida")
    puts("2. Unirse a una partida")
    puts("3. Ver partidas disponibles")
    puts("4. Volver al menú principal")

    case gets("Selecciona una opción: ") |> trim() do
      "1" ->
        create_multiplayer_room(session_id, user)

      "2" ->
        join_multiplayer_room(session_id, user)

      "3" ->
        list_available_rooms(session_id, user)

      "4" ->
        show_game_menu(session_id, user)

      _ ->
        puts("Opción inválida")
        show_multiplayer_menu(session_id, user)
    end
  end

  defp create_multiplayer_room(session_id, user) do
    puts("\n=== Crear Partida Multijugador ===")

    room_name = gets("Nombre de la partida: ") |> trim()

    max_players =
      case gets("Número máximo de jugadores (2-8): ") |> trim() |> Integer.parse() do
        {num, ""} when num in 2..8 ->
          num

        _ ->
          puts("Número inválido, usando 4 por defecto")
          4
      end

    # Seleccionar categoría - con manejo de errores
    categories =
      try do
        Trivia.QuestionBank.get_categories()
      rescue
        _ -> ["Ciencia", "Historia", "Deportes", "Geografía", "Arte"]
      end

    puts("\nSelecciona categoría:")
    puts("0. Todas las categorías")

    Enum.with_index(categories, 1)
    |> Enum.each(fn {category, index} ->
      puts("#{index}. #{category}")
    end)

    category =
      case gets("Categoría (0-#{length(categories)}): ") |> trim() |> Integer.parse() do
        {0, ""} ->
          nil

        {index, ""} when index >= 1 and index <= length(categories) ->
          Enum.at(categories, index - 1)

        _ ->
          puts("Opción inválida, usando todas las categorías")
          nil
      end

    num_questions =
      case gets("Número de preguntas (5-20): ") |> trim() |> Integer.parse() do
        {num, ""} when num in 5..20 ->
          num

        _ ->
          puts("Número inválido, usando 10 por defecto")
          10
      end

    # Usar el nuevo sistema de partidas
    case Trivia.GameSupervisor.create_game(category || "general", num_questions, 15, max_players) do
      {:ok, game_pid, game_id} ->
        # Unir al creador
        case Trivia.Game.join_game(game_pid, user.username) do
          {:ok, _game_state} ->
            puts("\n¡Partida creada exitosamente!")
            puts("ID de la partida: #{game_id}")
            puts("Nombre: #{room_name}")
            puts("Jugadores: 1/#{max_players}")
            puts("Categoría: #{category || "Todas"}")
            puts("Preguntas: #{num_questions}")
            puts("\nComparte este ID con otros jugadores: #{game_id}")
            puts("\nEsperando jugadores...")

            wait_for_players(session_id, user, game_pid, game_id)

          {:error, reason} ->
            puts("Error al unirse a la partida: #{reason}")
            show_multiplayer_menu(session_id, user)
        end

      {:error, reason} ->
        puts("Error al crear partida: #{reason}")
        show_multiplayer_menu(session_id, user)
    end

    # Usar el nuevo sistema de partidas
    case Trivia.GameSupervisor.create_game(category || "general", num_questions, 15, max_players) do
      {:ok, game_pid, game_id} ->
        # Unir al creador
        case Trivia.Game.join_game(game_pid, user.username) do
          {:ok, _game_state} ->
            puts("\n🎉 ¡Partida creada exitosamente!")
            puts("ID de la partida: #{game_id}")
            puts("Nombre: #{room_name}")
            puts("Jugadores: 1/#{max_players}")
            puts("Categoría: #{category || "Todas"}")
            puts("Preguntas: #{num_questions}")
            puts("\nComparte este ID con otros jugadores: #{game_id}")
            puts("\nEsperando jugadores...")

            wait_for_players(session_id, user, game_pid, game_id)

          {:error, reason} ->
            puts("Error al unirse a la partida: #{reason}")
            show_multiplayer_menu(session_id, user)
        end

      {:error, reason} ->
        puts("Error al crear partida: #{reason}")
        show_multiplayer_menu(session_id, user)
    end
  end

  defp wait_for_players(session_id, user, game_pid, game_id) do
    case Trivia.Game.get_game_state(game_pid) do
      {:ok, game_state} ->
        show_room_status(game_state)

        puts("\nOpciones:")
        puts("1. Actualizar lista de jugadores")
        puts("2. Iniciar partida")
        puts("3. Cancelar partida")

        case gets("Selecciona una opción: ") |> trim() do
          "1" ->
            wait_for_players(session_id, user, game_pid, game_id)

          "2" ->
            case Trivia.Game.start_game(game_pid, user.username) do
              {:ok, _} ->
                puts("¡Partida iniciada!")
                start_multiplayer_game(session_id, user, game_pid)

              {:error, reason} ->
                puts("Error al iniciar partida: #{reason}")
                wait_for_players(session_id, user, game_pid, game_id)
            end

          "3" ->
            # El proceso se cerrará automáticamente cuando termine
            puts("Partida cancelada")
            show_multiplayer_menu(session_id, user)

          _ ->
            puts("Opción inválida")
            wait_for_players(session_id, user, game_pid, game_id)
        end

      {:error, _} ->
        puts("La partida ya no existe")
        show_multiplayer_menu(session_id, user)
    end
  end

  defp show_room_status(game_state) do
    puts("\n=== Estado de la Partida ===")
    puts("ID: #{game_state.id}")
    puts("Tema: #{game_state.topic}")
    puts("Creador: #{game_state.creator}")
    puts("Jugadores (#{map_size(game_state.players)}/#{game_state.max_players}):")

    Enum.each(game_state.players, fn {username, player} ->
      creator_indicator = if username == game_state.creator, do: " ", else: ""
      puts("  - #{username}#{creator_indicator} (#{player.score} puntos)")
    end)
  end

  defp join_multiplayer_room(session_id, user) do
    puts("\n=== Unirse a Partida ===")

    game_id = gets("ID de la partida: ") |> trim()

    case find_game_by_id(game_id) do
      {:ok, game_pid} ->
        case Trivia.Game.join_game(game_pid, user.username) do
          {:ok, game_state} ->
            puts("\n¡Te has unido a la partida!")
            puts("Tema: #{game_state.topic}")
            puts("Creador: #{game_state.creator}")
            puts("Jugadores: #{map_size(game_state.players)}/#{game_state.max_players}")

            if game_state.status == :playing do
              puts("¡La partida ya está en juego!")
              start_multiplayer_game(session_id, user, game_pid)
            else
              wait_for_game_start(session_id, user, game_pid, game_id)
            end

          {:error, reason} ->
            puts("Error al unirse a la partida: #{reason}")
            show_multiplayer_menu(session_id, user)
        end

      :not_found ->
        puts("Partida no encontrada")
        show_multiplayer_menu(session_id, user)
    end
  end

  defp wait_for_game_start(session_id, user, game_pid, game_id) do
    puts("\nEsperando a que el creador inicie la partida...")
    puts("1. Actualizar estado")
    puts("2. Abandonar partida")

    case gets("Selecciona una opción: ") |> trim() do
      "1" ->
        case Trivia.Game.get_game_state(game_pid) do
          {:ok, game_state} ->
            if game_state.status == :playing do
              puts("¡La partida ha comenzado!")
              start_multiplayer_game(session_id, user, game_pid)
            else
              show_room_status(game_state)
              wait_for_game_start(session_id, user, game_pid, game_id)
            end

          {:error, _} ->
            puts("La partida ya no existe")
            show_multiplayer_menu(session_id, user)
        end

      "2" ->
        # En este sistema simple, simplemente salimos del menú
        puts("Has abandonado la partida")
        show_multiplayer_menu(session_id, user)

      _ ->
        puts("Opción inválida")
        wait_for_game_start(session_id, user, game_pid, game_id)
    end
  end

  defp list_available_rooms(_session_id, user) do
    games = Trivia.GameSupervisor.list_games()

    puts("\n=== Partidas Disponibles ===")

    if Enum.empty?(games) do
      puts("No hay partidas disponibles")
      puts("¡Crea una nueva partida!")
    else
      Enum.each(games, fn game ->
        status = if game.status == :waiting, do: "Esperando", else: "En juego"
        puts("\nID: #{game.id}")
        puts("Tema: #{game.topic}")
        puts("Creador: #{game.creator}")
        puts("Jugadores: #{map_size(game.players)}/#{game.max_players}")
        puts("Estado: #{status}")
      end)
    end

    show_multiplayer_menu(nil, user)
  end

  defp start_multiplayer_game(session_id, user, game_pid) do
    case Trivia.Game.get_game_state(game_pid) do
      {:ok, game_state} ->
        if game_state.status == :playing do
          play_multiplayer_loop(session_id, user, game_pid, game_state)
        else
          puts("La partida aún no ha comenzado")
          show_multiplayer_menu(session_id, user)
        end

      {:error, reason} ->
        puts("Error: #{reason}")
        show_multiplayer_menu(session_id, user)
    end
  end

  defp play_multiplayer_loop(session_id, user, game_pid, game_state) do
    if game_state.current_question do
      # Mostrar pregunta actual
      question = game_state.current_question

      puts("\n" <> String.duplicate("=", 50))
      puts("Pregunta ##{game_state.current_question_index}/#{game_state.total_questions}")
      puts("Categoría: #{question.category}")
      puts("Tu puntuación: #{game_state.scores[user.username] || 0}")
      puts(String.duplicate("=", 50))
      puts("\n#{question.question}")

      Enum.with_index(question.all_answers, 1)
      |> Enum.each(fn {answer, index} ->
        puts("#{index}. #{answer}")
      end)

      puts("\nTienes #{game_state.time_limit} segundos para responder")
      puts("Usa: answer #{game_state.current_question_index} <número_respuesta>")

      # Esperar respuesta del usuario
      wait_for_answer(session_id, user, game_pid, game_state)
    else
      # Juego terminado, mostrar resultados
      show_multiplayer_results(game_state)
      show_game_menu(session_id, user)
    end
  end

  defp wait_for_answer(session_id, user, game_pid, game_state) do
    input = gets("\nTu comando: ") |> trim()

    case String.split(input) do
      ["answer", _question_idx, answer_letter] ->
        case Integer.parse(answer_letter) do
          {answer_num, ""} when answer_num in 1..4 ->
            # Convertir número a letra (1=A, 2=B, etc.)
            answer = ["A", "B", "C", "D"] |> Enum.at(answer_num - 1)

            case Trivia.Game.answer_question(
                   game_pid,
                   user.username,
                   game_state.current_question_index,
                   answer
                 ) do
              {:ok, result} ->
                if result.correct do
                  puts("¡Correcto! +10 puntos")
                else
                  puts("Incorrecto. -5 puntos")
                end

                puts("Tu puntuación actual: #{result.score}")

                # Esperar siguiente pregunta
                Process.sleep(2000)

                case Trivia.Game.get_game_state(game_pid) do
                  {:ok, new_state} -> play_multiplayer_loop(session_id, user, game_pid, new_state)
                  _ -> show_game_menu(session_id, user)
                end

              {:error, reason} ->
                puts("Error: #{reason}")
                wait_for_answer(session_id, user, game_pid, game_state)
            end

          _ ->
            puts("Respuesta inválida. Usa un número del 1 al 4")
            wait_for_answer(session_id, user, game_pid, game_state)
        end

      _ ->
        puts("Comando inválido. Usa: answer <número_pregunta> <número_respuesta>")
        wait_for_answer(session_id, user, game_pid, game_state)
    end
  end

  defp show_multiplayer_results(game_state) do
    ranking =
      game_state.players
      |> Map.values()
      |> Enum.sort_by(& &1.score, :desc)

    puts("\n=== PARTIDA TERMINADA ===")
    puts("Ranking Final:")

    Enum.with_index(ranking, 1)
    |> Enum.each(fn {player, index} ->
      medal =
        case index do
          1 -> "1"
          2 -> "2"
          3 -> "3"
          _ -> "#{index}."
        end

      puts("#{medal} #{player.username}: #{player.score} puntos")
    end)
  end

  defp find_game_by_id(game_id) do
    Trivia.GameSupervisor.list_games()
    |> Enum.find(fn game -> game.id == game_id end)
    |> case do
      nil ->
        :not_found

      _game ->
        # Buscar el PID del proceso del juego
        DynamicSupervisor.which_children(Trivia.GameSupervisor)
        |> Enum.find(fn {_, pid, _, _} ->
          case Trivia.Game.get_game_state(pid) do
            {:ok, state} -> state.id == game_id
            _ -> false
          end
        end)
        |> case do
          {_, pid, _, _} -> {:ok, pid}
          nil -> :not_found
        end
    end
  end

  # ... (mantener las funciones individuales del juego existentes)
  defp start_quick_game(session_id, user) do
    puts("\nIniciando Trivia Rápida")
    puts("5 preguntas |  30 segundos por pregunta")
    start_game_with_settings(session_id, user, nil, 5, 30)
  end

  defp start_standard_game(session_id, user) do
    puts("\nIniciando Trivia Estándar")
    puts("10 preguntas |  Sin límite de tiempo")
    start_game_with_settings(session_id, user, nil, 10, 0)
  end

  defp start_custom_game(session_id, user) do
    puts("\nConfiguración Personalizada")

    num_questions =
      case gets("Número de preguntas (1-20): ") |> trim() |> Integer.parse() do
        {num, ""} when num >= 1 and num <= 20 ->
          num

        _ ->
          puts("Número inválido, usando 10 por defecto")
          10
      end

    time_limit =
      case gets("Tiempo límite por pregunta en segundos (0 = sin límite): ")
           |> trim()
           |> Integer.parse() do
        {time, ""} when time >= 0 ->
          time

        _ ->
          puts("Tiempo inválido, usando sin límite")
          0
      end

    puts("\nIniciando Trivia Personalizada")

    puts(
      "#{num_questions} preguntas |  #{if time_limit > 0, do: "#{time_limit} segundos", else: "Sin límite"}"
    )

    start_game_with_settings(session_id, user, nil, num_questions, time_limit)
  end

  defp start_game_by_category(session_id, user) do
    categories = Trivia.QuestionBank.get_categories()

    puts("\n=== Selecciona una categoría ===")

    Enum.with_index(categories, 1)
    |> Enum.each(fn {category, index} ->
      questions = Trivia.QuestionBank.get_questions_by_category(category)
      puts("#{index}. #{category} (#{length(questions)} preguntas)")
    end)

    input = gets("Selecciona una categoría (número): ") |> trim()

    case Integer.parse(input) do
      {index, ""} when index >= 1 and index <= length(categories) ->
        category = Enum.at(categories, index - 1)

        num_questions =
          case gets("Número de preguntas (1-20): ") |> trim() |> Integer.parse() do
            {num, ""} when num >= 1 and num <= 20 -> num
            _ -> 10
          end

        time_limit =
          case gets("Tiempo límite por pregunta en segundos (0 = sin límite): ")
               |> trim()
               |> Integer.parse() do
            {time, ""} when time >= 0 -> time
            _ -> 0
          end

        start_game_with_settings(session_id, user, category, num_questions, time_limit)

      _ ->
        puts("Categoría inválida")
        show_game_menu(session_id, user)
    end
  end

  defp start_game_with_settings(session_id, user, category, num_questions, time_limit) do
    case Trivia.IndividualGame.start_game_with_settings(
           session_id,
           category,
           num_questions,
           time_limit
         ) do
      {:ok, game_state} ->
        play_game_loop(session_id, game_state, category || "Todas")

      {:error, reason} ->
        puts("Error al iniciar juego: #{reason}")
        show_game_menu(session_id, user)
    end
  end

  defp play_game_loop(session_id, game_state, category) do
    question = game_state.current_question

    puts("\n" <> String.duplicate("=", 50))
    puts("Pregunta ##{game_state.questions_answered + 1}/#{game_state.max_questions}")
    puts("Categoría: #{question.category}")
    puts("Puntuación actual: #{game_state.score}")
    puts(String.duplicate("=", 50))
    puts("\n#{question.question}")

    Enum.with_index(question.all_answers, 1)
    |> Enum.each(fn {answer, index} ->
      puts("#{index}. #{answer}")
    end)

    if game_state.time_limit > 0 do
      puts("\nTienes #{game_state.time_limit} segundos para responder")
    end

    start_time = System.system_time(:second)
    answer_result = read_answer_with_timeout(length(question.all_answers), game_state.time_limit)

    case answer_result do
      {:ok, answer_index} ->
        selected_answer = Enum.at(question.all_answers, answer_index - 1)
        time_taken = System.system_time(:second) - start_time

        # Verificar si se excedió el tiempo
        final_time_taken =
          if game_state.time_limit > 0 and time_taken > game_state.time_limit do
            puts("\n¡Tiempo agotado! La respuesta correcta era: #{question.correct_answer}")
            game_state.time_limit
          else
            time_taken
          end

        process_answer(
          session_id,
          game_state,
          category,
          selected_answer,
          final_time_taken,
          question.correct_answer
        )

      {:timeout} ->
        puts("\n¡Tiempo agotado! La respuesta correcta era: #{question.correct_answer}")

        case Trivia.IndividualGame.answer_question(session_id, "", game_state.time_limit) do
          {:ok, :continue, new_state} ->
            play_game_loop(session_id, new_state, category)

          {:ok, :game_over, final_state} ->
            end_game(session_id, final_state, category)

          {:error, reason} ->
            puts("Error: #{reason}")
            show_game_menu(session_id, game_state.user)
        end

      {:error, reason} ->
        puts("Error: #{reason}")
        play_game_loop(session_id, game_state, category)
    end
  end

  defp read_answer_with_timeout(max_options, time_limit) do
    if time_limit > 0 do
      task =
        Task.async(fn ->
          gets("\nTu respuesta (1-#{max_options}): ") |> trim()
        end)

      case Task.yield(task, time_limit * 1000) || Task.shutdown(task) do
        {:ok, input} -> parse_answer_input(input, max_options)
        nil -> {:timeout}
      end
    else
      input = gets("\nTu respuesta (1-#{max_options}): ") |> trim()
      parse_answer_input(input, max_options)
    end
  end

  defp parse_answer_input(input, max_options) do
    case Integer.parse(input) do
      {answer_index, ""} when answer_index >= 1 and answer_index <= max_options ->
        {:ok, answer_index}

      _ ->
        {:error, "Por favor ingresa un número entre 1 y #{max_options}"}
    end
  end

  defp process_answer(
         session_id,
         game_state,
         category,
         selected_answer,
         time_taken,
         correct_answer
       ) do
    case Trivia.IndividualGame.answer_question(session_id, selected_answer, time_taken) do
      {:ok, :continue, new_state} ->
        if selected_answer == correct_answer and selected_answer != "" do
          points_earned = new_state.score - game_state.score
          puts("\n¡Correcto! +#{points_earned} puntos")
        else
          puts("\nIncorrecto. La respuesta correcta era: #{correct_answer}")
        end

        puts("Puntuación total: #{new_state.score}")
        play_game_loop(session_id, new_state, category)

      {:ok, :game_over, final_state} ->
        end_game(session_id, final_state, category)

      {:error, reason} ->
        puts("Error: #{reason}")
        show_game_menu(session_id, game_state.user)
    end
  end

  defp end_game(session_id, final_state, category) do
    puts("\n=== JUEGO TERMINADO ===")
    puts("Puntuación final: #{final_state.score}")
    puts("Preguntas respondidas: #{final_state.questions_answered}")
    puts("Categoría: #{category}")

    case Trivia.UserManager.get_user_by_session(session_id) do
      {:ok, user} -> show_game_menu(session_id, user)
      {:error, _} -> show_main_menu()
    end
  end

  defp show_my_score(user, session_id) do
    case Trivia.UserManager.get_user_by_session(session_id) do
      {:ok, current_user} ->
        puts("\n=== Tu Puntuación ===")
        puts("Usuario: #{current_user.username}")
        puts("Puntuación total: #{current_user.score}")
        puts("Juegos jugados: #{current_user.games_played}")

      {:error, _} ->
        puts("\nUsuario: #{user.username}")
        puts("Puntuación total: #{user.score}")
        puts("Juegos jugados: #{user.games_played}")
    end

    show_game_menu(session_id, user)
  end

  defp show_leaderboard do
    leaderboard = Trivia.UserManager.get_leaderboard()

    puts("\n=== Leaderboard ===")

    if Enum.empty?(leaderboard) do
      puts("Aún no hay puntuaciones registradas")
    else
      Enum.with_index(leaderboard, 1)
      |> Enum.each(fn {user, index} ->
        puts("#{index}. #{user.username} - #{user.score} puntos (#{user.games_played} juegos)")
      end)
    end

    show_main_menu()
  end

  defp show_categories do
    categories = Trivia.QuestionBank.get_categories()

    puts("\n=== Categorías Disponibles ===")

    Enum.with_index(categories, 1)
    |> Enum.each(fn {category, index} ->
      questions = Trivia.QuestionBank.get_questions_by_category(category)
      puts("#{index}. #{category} (#{length(questions)} preguntas)")
    end)

    show_main_menu()
  end

  defp register_user do
    username = gets("Usuario: ") |> trim()
    password = gets("Contraseña: ") |> trim()

    case Trivia.UserManager.register_user(username, password) do
      {:ok, message} ->
        puts(message)
        show_main_menu()

      {:error, reason} ->
        puts("Error: #{reason}")
        show_main_menu()
    end
  end

  defp login_user do
    username = gets("Usuario: ") |> trim()
    password = gets("Contraseña: ") |> trim()

    case Trivia.UserManager.login_user(username, password) do
      {:ok, session_id, user} ->
        puts("¡Bienvenido #{user.username}!")
        show_game_menu(session_id, user)

      {:error, reason} ->
        puts("Error: #{reason}")
        show_main_menu()
    end
  end
end
