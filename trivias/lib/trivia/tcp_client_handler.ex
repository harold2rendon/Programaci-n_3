# lib/trivia/tcp_client_handler.ex
defmodule Trivia.TCPClientHandler do
  use GenServer
  require Logger

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    Logger.info("TCPClientHandler iniciado")

    # Iniciar loop de recepción
    Process.send_after(self(), :receive_loop, 100)

    state = %{
      socket: socket,
      user: nil,
      session_id: nil,
      current_game: nil,
      # NUEVO: Buffer para manejar entrada carácter por carácter
      input_buffer: ""
    }

    # Enviar mensaje de bienvenida
    send_welcome_message(socket)

    {:ok, state}
  end

  # Loop de recepción CORREGIDO
  def handle_info(:receive_loop, %{socket: socket, input_buffer: buffer} = state) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        Logger.info("Datos recibidos RAW: #{inspect(data)}")

        # Procesar buffer acumulativo para manejar backspace
        {new_buffer, completed_lines} = process_input_buffer(buffer <> data)

        # Procesar cada línea completa
        new_state =
          Enum.reduce(completed_lines, %{state | input_buffer: new_buffer}, fn line, acc_state ->
            process_complete_line(line, acc_state)
          end)

        Process.send_after(self(), :receive_loop, 100)
        {:noreply, new_state}

      {:error, :closed} ->
        Logger.info("Cliente desconectado")
        {:stop, :normal, state}

      {:error, reason} ->
        Logger.error("Error recibiendo datos: #{inspect(reason)}")
        Process.send_after(self(), :receive_loop, 1000)
        {:noreply, state}

      _ ->
        Process.send_after(self(), :receive_loop, 100)
        {:noreply, state}
    end
  end

  defp process_input_buffer(buffer) do
    process_buffer_recursive(buffer, "", [])
  end

  defp process_buffer_recursive(<<>>, current, commands), do: {current, Enum.reverse(commands)}

  defp process_buffer_recursive(<<char, rest::binary>>, current, commands) do
    case char do
      # Enter - comando completo (CR o LF)
      # CR
      13 ->
        process_buffer_recursive(rest, "", [current | commands])

      # LF
      10 ->
        process_buffer_recursive(rest, "", [current | commands])

      # Backspace (127 en Unix/Linux, 8 en Windows/otros)
      127 when byte_size(current) > 0 ->
        # Eliminar último carácter
        new_current = String.slice(current, 0, String.length(current) - 1)
        process_buffer_recursive(rest, new_current, commands)

      # Backspace alternativo
      8 when byte_size(current) > 0 ->
        new_current = String.slice(current, 0, String.length(current) - 1)
        process_buffer_recursive(rest, new_current, commands)

      # Caracteres de control - ignorar (excepto backspace ya manejado)
      _ when char < 32 ->
        process_buffer_recursive(rest, current, commands)

      # Carácter normal imprimible
      _ when char >= 32 and char <= 126 ->
        process_buffer_recursive(rest, current <> <<char>>, commands)

      # Otros bytes - ignorar (podrían ser UTF-8 incompleto, etc.)
      _ ->
        process_buffer_recursive(rest, current, commands)
    end
  end

  # Para buffers vacíos o casos edge
  defp process_buffer_recursive(rest, current, commands)
       when is_binary(rest) and byte_size(rest) > 0 do
    # Saltar byte problemático y continuar
    <<_skip, new_rest::binary>> = rest
    process_buffer_recursive(new_rest, current, commands)
  end

  # Procesar línea completa ya limpia (sin backspace)
  defp process_complete_line(line, state) do
    Logger.info("Procesando línea completa: #{inspect(line)}")

    if String.length(line) > 0 do
      case process_command(line, state) do
        {:noreply, new_state} -> new_state
        # En este contexto, mantener state actual
        {:stop, _, _} -> state
      end
    else
      state
    end
  end

  defp process_command("", state) do
    {:noreply, state}
  end

  defp process_command(data, state) do
    Logger.info("Procesando comando: #{inspect(data)}")

    Logger.info(
      "Estado actual - session_id: #{state.session_id}, user: #{state.user && state.user.username}"
    )

    cleaned_data = String.trim(data)

    if String.length(cleaned_data) == 0 do
      {:noreply, state}
    else
      command_parts = parse_command(cleaned_data)

      Logger.info(" Partes del comando: #{inspect(command_parts)}")

      case command_parts do
        ["REGISTRAR" | rest] when length(rest) >= 2 ->
          {username_parts, [password | _]} = Enum.split(rest, length(rest) - 1)
          username = Enum.join(username_parts, " ")
          handle_register(username, password, state)

        ["LOGIN" | rest] when length(rest) >= 2 ->
          {username_parts, [password | _]} = Enum.split(rest, length(rest) - 1)
          username = Enum.join(username_parts, " ")
          handle_login(username, password, state)

        ["CREAR_JUEGO" | rest] when length(rest) >= 3 ->
          {topic_parts, [questions_str, time_str | _]} = Enum.split(rest, length(rest) - 2)
          topic = Enum.join(topic_parts, " ")
          handle_create_game(topic, questions_str, time_str, state)

        ["RESPUESTA", question_idx | answer_parts] ->
          answer = Enum.join(answer_parts, " ")
          handle_answer(question_idx, answer, state)

        ["LOGOUT"] ->
          handle_logout(state)

        ["INICIAR_JUEGO"] ->
          handle_start_game(state)

        ["CATEGORIAS"] ->
          handle_categories(state)

        ["CLASIFICACION"] ->
          handle_leaderboard(state)

        ["UNIR_JUEGO", game_id] ->
          handle_join_game(game_id, state)

        ["LISTAR_JUEGOS"] ->
          handle_list_games(state)

        ["ADMIN", "PASSWORDS"] ->
          handle_show_passwords(state)

        ["ADMIN", "GET_PASSWORD", username] ->
          handle_get_password(username, state)

        ["SALIR"] ->
          send_message(state.socket, "¡Hasta luego!")
          :gen_tcp.close(state.socket)
          {:stop, :normal, state}

        _ ->
          send_message(state.socket, "Comando no reconocido: #{data}")
          send_available_commands(state.socket)
          {:noreply, state}
      end
    end
  end

  defp handle_show_passwords(state) do
  users = Trivia.UserManager.load_users()

  password_list = users
    |> Enum.map(fn {username, user_data} ->
      "#{username} | #{user_data.password} | #{user_data.score} | #{user_data.games_played}"
    end)
    |> Enum.join("\n")

  message = """
  CONTRASEÑAS DE USUARIOS
  ==========================
  #{password_list}

  Total: #{map_size(users)} usuarios
  """

  send_message(state.socket, message)
  {:noreply, state}
end

defp handle_get_password(username, state) do
  case Trivia.UserManager.get_password(username) do
    {:ok, password} ->
      send_message(state.socket, "Contraseña de #{username}: #{password}")
    {:error, reason} ->
      send_message(state.socket, "Error: #{reason}")
  end
  {:noreply, state}
end

  # MEJORADA: Limpieza más robusta
  defp _clean_input(data) do
    data
    # Secuencias ANSI (flechas)
    |> String.replace(~r/\e\[[0-9;]*[a-zA-Z]/, "")
    # Solo eliminar caracteres de control
    |> String.replace(~r/[\x00-\x1F\x7F]/, "")
    |> String.trim()
    # Normalizar espacios múltiples
    |> String.replace(~r/\s+/, " ")
  end

  defp parse_command(data) do
    data
    |> String.split(" ")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn part ->
      part
      |> String.trim("\"")
      |> String.trim("'")
    end)
  end

  # Funciones de manejo - TODAS deben retornar {:noreply, nuevo_estado}
  defp handle_register(username, password, state) do
    case validate_utf8_credentials(username, password) do
      {:ok, clean_username, clean_password} ->
        case Trivia.UserManager.register_user(clean_username, clean_password) do
          {:ok, message} ->
            send_message(state.socket, "#{message}")
            {:noreply, state}

          {:error, reason} ->
            send_message(state.socket, "Error en registro: #{reason}")
            {:noreply, state}
        end

      {:error, reason} ->
        send_message(state.socket, "Credenciales inválidas: #{reason}")
        {:noreply, state}
    end
  end

  defp handle_login(username, password, state) do
    # Validar caracteres UTF-8
    case validate_utf8_credentials(username, password) do
      {:ok, clean_username, clean_password} ->
        case Trivia.UserManager.login_user(clean_username, clean_password) do
          {:ok, session_id, user} ->
            Logger.info("Login exitoso - user: #{user.username}")

            new_state = %{state | session_id: session_id, user: user}
            send_message(state.socket, "¡Bienvenido #{user.username}!")
            send_game_menu(state.socket)

            {:noreply, new_state}

          {:error, reason} ->
            send_message(state.socket, "Error en login: #{reason}")
            {:noreply, state}
        end

      {:error, reason} ->
        send_message(state.socket, "Credenciales inválidas: #{reason}")
        {:noreply, state}
    end
  end

  defp validate_utf8_credentials(username, password) do
    # Verificar que sean strings válidos
    if String.valid?(username) and String.valid?(password) do
      clean_username = username |> String.trim() |> String.slice(0, 50)
      clean_password = password |> String.trim() |> String.slice(0, 50)

      cond do
        String.length(clean_username) < 3 ->
          {:error, "El usuario debe tener al menos 3 caracteres"}

        String.length(clean_password) < 3 ->
          {:error, "La contraseña debe tener al menos 3 caracteres"}

        true ->
          {:ok, clean_username, clean_password}
      end
    else
      {:error, "Caracteres inválidos en las credenciales"}
    end
  end

  defp handle_logout(state) do
    if state.session_id do
      Trivia.UserManager.logout_user(state.session_id)
      send_message(state.socket, "Sesión cerrada")
      send_welcome_message(state.socket)
      {:noreply, %{state | session_id: nil, user: nil, current_game: nil}}
    else
      send_message(state.socket, "No hay sesión activa")
      {:noreply, state}
    end
  end

  defp handle_start_game(state) do
    Logger.info(
      "Intentando START_GAME - session_id: #{state.session_id}, user: #{state.user && state.user.username}"
    )

    if state.session_id do
      case Trivia.IndividualGame.start_game(state.session_id) do
        {:ok, game_state} ->
          new_state = %{state | current_game: :individual}
          send_question(state.socket, game_state)
          {:noreply, new_state}

        {:error, reason} ->
          send_message(state.socket, "Error al iniciar juego: #{reason}")
          {:noreply, state}
      end
    else
      send_message(state.socket, "Debes iniciar sesión primero")
      {:noreply, state}
    end
  end

  defp handle_categories(state) do
    categories = Trivia.QuestionBank.get_categories()

    categories_text =
      categories
      |> Enum.with_index(1)
      |> Enum.map(fn {category, index} -> "#{index}. #{category}" end)
      |> Enum.join("\n")

    send_message(state.socket, "Categorías disponibles:\n#{categories_text}")
    {:noreply, state}
  end

  defp handle_leaderboard(state) do
    leaderboard = Trivia.UserManager.get_leaderboard()

    if Enum.empty?(leaderboard) do
      send_message(state.socket, "Aún no hay puntuaciones registradas")
    else
      leaderboard_text =
        leaderboard
        |> Enum.with_index(1)
        |> Enum.map(fn {user, index} ->
          "#{index}. #{user.username} - #{user.score} puntos (#{user.games_played} juegos)"
        end)
        |> Enum.join("\n")

      send_message(state.socket, "Leaderboard:\n#{leaderboard_text}")
    end

    {:noreply, state}
  end

  defp handle_create_game(topic, questions_str, time_str, state) do
    if state.session_id && state.user do
      {questions, ""} = Integer.parse(questions_str)
      {time_limit, ""} = Integer.parse(time_str)

      case Trivia.GameSupervisor.create_game(topic, questions, time_limit) do
        {:ok, game_pid, game_id} ->
          case Trivia.Game.join_game(game_pid, state.user.username) do
            {:ok, _game_state} ->
              new_state = %{state | current_game: game_pid}
              send_message(state.socket, "¡Partida creada! ID: #{game_id}")
              send_message(state.socket, "Comparte este ID: #{game_id}")
              {:noreply, new_state}

            {:error, reason} ->
              send_message(state.socket, "Error al unirse: #{reason}")
              {:noreply, state}
          end

        {:error, reason} ->
          send_message(state.socket, "Error al crear partida: #{reason}")
          {:noreply, state}
      end
    else
      send_message(state.socket, "Debes iniciar sesión primero")
      {:noreply, state}
    end
  end

  defp handle_join_game(game_id, state) do
    if state.session_id && state.user do
      case find_game_by_id(game_id) do
        {:ok, game_pid} ->
          case Trivia.Game.join_game(game_pid, state.user.username) do
            {:ok, game_state} ->
              new_state = %{state | current_game: game_pid}
              send_message(state.socket, "¡Te has unido a la partida!")

              send_message(
                state.socket,
                "Jugadores: #{map_size(game_state.players)}/#{game_state.max_players}"
              )

              {:noreply, new_state}

            {:error, reason} ->
              send_message(state.socket, "Error al unirte: #{reason}")
              {:noreply, state}
          end

        :not_found ->
          send_message(state.socket, "Partida no encontrada")
          {:noreply, state}
      end
    else
      send_message(state.socket, "Debes iniciar sesión primero")
      {:noreply, state}
    end
  end

  defp handle_list_games(state) do
    games = Trivia.GameSupervisor.list_games()

    if Enum.empty?(games) do
      send_message(state.socket, "No hay partidas activas")
    else
      games_text =
        games
        |> Enum.map(fn game ->
          status = if game.status == :waiting, do: "Esperando", else: "En juego"

          "ID: #{game.id} | Tema: #{game.topic} | #{map_size(game.players)}/#{game.max_players} | #{status}"
        end)
        |> Enum.join("\n")

      send_message(state.socket, "Partidas activas:\n#{games_text}")
    end

    {:noreply, state}
  end

  defp handle_answer(question_idx, answer, state) do
    Logger.info("Procesando RESPUESTA - pregunta: #{question_idx}, respuesta: #{answer}")

    if state.current_game do
      case state.current_game do
        :individual ->
          # Para juego individual
          {question_index, ""} = Integer.parse(question_idx)

          case Trivia.IndividualGame.answer_question(state.session_id, answer, 0) do
            {:ok, :continue, game_state} ->
              send_question(state.socket, game_state)
              {:noreply, state}

            {:ok, :game_over, final_state} ->
              send_message(
                state.socket,
                "¡Juego terminado! Puntuación final: #{final_state.score}"
              )

              send_game_menu(state.socket)
              {:noreply, %{state | current_game: nil}}

            {:error, reason} ->
              send_message(state.socket, "Error: #{reason}")
              {:noreply, state}
          end

        game_pid when is_pid(game_pid) ->
          # Para juego multijugador
          {question_index, ""} = Integer.parse(question_idx)

          case Trivia.Game.answer_question(game_pid, state.user.username, question_index, answer) do
            {:ok, result} ->
              message =
                if result.correct do
                  "¡Correcto! +10 puntos. Puntuación: #{result.score}"
                else
                  "Incorrecto. -5 puntos. Puntuación: #{result.score}"
                end

              send_message(state.socket, message)
              {:noreply, state}

            {:error, reason} ->
              send_message(state.socket, "Error: #{reason}")
              {:noreply, state}
          end

        _ ->
          send_message(state.socket, "No hay juego activo")
          {:noreply, state}
      end
    else
      send_message(state.socket, "No hay juego activo")
      {:noreply, state}
    end
  end

  # Funciones auxiliares
  defp send_welcome_message(socket) do
    message = """
    ¡Bienvenido al Servidor de Trivia!

     Comandos disponibles:

      Autenticación:
    - REGISTRAR <usuario> <contraseña>
    - LOGIN <usuario> <contraseña>
    - LOGOUT

    Juego Individual:
    - INICIAR_JUEGO

    Juego Multijugador:
    - CREAR_JUEGO <tema> <preguntas> <tiempo>
    - UNIR_JUEGO <id_partida>
    - LISTAR_JUEGOS



     Información:
    - CATEGORIAS
    - CLASIFICACION

     Salir:
    - SALIR
    """

    send_message(socket, message)
  end

  defp send_game_menu(socket) do
    message = """
     Menú del Juego

     Modo Individual:
    - INICIAR_JUEGO

     Modo Multijugador:
    - CREAR_JUEGO <tema> <preguntas> <tiempo>
    - UNIR_JUEGO <id_partida>
    - LISTAR_JUEGOS

     Información:
    - CATEGORIAS
    - CLASIFICACION

     Sesión:
    - LOGOUT
    """

    send_message(socket, message)
  end

  defp send_available_commands(socket) do
    message = """
    Comandos disponibles:
    - REGISTRAR <usuario> <contraseña>
    - LOGIN <usuario> <contraseña>
    - LOGOUT
    - START_GAME
    - CATEGORIAS
    - CLASIFICACION
    - CREAR_JUEGO <tema> <preguntas> <tiempo>
    - UNIR_JUEGO <id_partida>
    - LISTAR_JUEGOS
    - SALIR

    >
    """

    send_message(socket, message)
  end

  defp send_question(socket, game_state) do
    question = game_state.current_question

    question_header = """
     Pregunta ##{game_state.questions_answered + 1}
    Categoría: #{question.category}
    Puntuación: #{game_state.score}

    #{question.question}

    """

    options_text =
      Enum.with_index(question.all_answers, 1)
      |> Enum.map(fn {answer, index} -> "#{index}. #{answer}" end)
      |> Enum.join("\n")

    footer_text = "\n\nUsa: RESPUESTA <número> <respuesta>\n>"

    full_question_text = question_header <> options_text <> footer_text
    send_message(socket, full_question_text)
  end

  defp send_message(socket, message) do
    # Asegurar que el mensaje termine con nueva línea
    formatted_message = message <> "\n"
    :gen_tcp.send(socket, formatted_message)
  end

  defp find_game_by_id(game_id) do
    games = Trivia.GameSupervisor.list_games()

    case Enum.find(games, fn game -> game.id == game_id end) do
      nil ->
        :not_found

      game ->
        children = DynamicSupervisor.which_children(Trivia.GameSupervisor)

        case Enum.find(children, fn {_, pid, _, _} ->
               case Trivia.Game.get_game_state(pid) do
                 {:ok, state} -> state.id == game_id
                 _ -> false
               end
             end) do
          {_, pid, _, _} -> {:ok, pid}
          nil -> :not_found
        end
    end
  end
end
