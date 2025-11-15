defmodule Trivia.UserManager do
  use GenServer
  require Logger

  # Archivo donde se guardan los usuarios
  @users_file "data/users.dat"

  # Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def register_user(username, password) do
    GenServer.call(__MODULE__, {:register, username, password})
  end

  def login_user(username, password) do
    GenServer.call(__MODULE__, {:login, username, password})
  end

  def logout_user(session_id) do
    GenServer.call(__MODULE__, {:logout, session_id})
  end

  def get_user_by_session(session_id) do
    GenServer.call(__MODULE__, {:get_user_by_session, session_id})
  end

  def get_leaderboard do
    GenServer.call(__MODULE__, :get_leaderboard)
  end

  def update_user_score(username, score, topic) do
    GenServer.call(__MODULE__, {:update_score, username, score, topic})
  end

  # Funciones administrativas
  def show_all_passwords do
    GenServer.call(__MODULE__, :show_all_passwords)
  end

  def get_user_password(username) do
    GenServer.call(__MODULE__, {:get_password, username})
  end

  # Función para ver el archivo directamente
  def view_raw_file do
    case File.read(@users_file) do
      {:ok, content} ->
        IO.puts(" CONTENIDO CRUDO DE #{@users_file}:")
        IO.puts(content)
        content

      {:error, reason} ->
        IO.puts(" Error leyendo archivo: #{reason}")
        nil
    end
  end

  # Server callbacks
  def terminate(_reason, _state) do
    :ok
  end

  def init(_state) do
    File.mkdir_p!("data")

    users = load_users_from_file()

    Logger.info(
      "UserManager iniciado con #{map_size(users)} usuarios cargados desde #{@users_file}"
    )

    {:ok, %{users: users, sessions: %{}}}
  end

  def handle_call({:register, username, password}, _from, state) do
    username = String.downcase(username)

    if Map.has_key?(state.users, username) do
      {:reply, {:error, "El usuario ya existe"}, state}
    else
      user_data = %{
        password: password,
        score: 0,
        games_played: 0,
        favorite_topic: nil
      }

      save_user_to_file(username, user_data)

      new_users = Map.put(state.users, username, user_data)
      new_state = %{state | users: new_users}

      Logger.info("Usuario registrado: #{username} en #{@users_file}")
      {:reply, {:ok, "Usuario #{username} registrado exitosamente"}, new_state}
    end
  end

  def handle_call({:login, username, password}, _from, state) do
    username = String.downcase(username)

    case Map.get(state.users, username) do
      nil ->
        {:reply, {:error, "Usuario no encontrado"}, state}

      user_data ->
        if password == user_data.password do
          session_id = generate_session_id()
          user_with_username = Map.put(user_data, :username, username)

          new_sessions = Map.put(state.sessions, session_id, username)
          new_state = %{state | sessions: new_sessions}

          Logger.info("Acceso exitoso: #{username}")
          {:reply, {:ok, session_id, user_with_username}, new_state}
        else
          {:reply, {:error, "Contraseña incorrecta"}, state}
        end
    end
  end

  def handle_call({:logout, session_id}, _from, state) do
    new_sessions = Map.delete(state.sessions, session_id)
    new_state = %{state | sessions: new_sessions}
    {:reply, :ok, new_state}
  end

  def handle_call({:get_user_by_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, "Sesión no válida"}, state}

      username ->
        user_data = Map.get(state.users, username)
        user_with_username = Map.put(user_data, :username, username)
        {:reply, {:ok, user_with_username}, state}
    end
  end

  def handle_call(:get_leaderboard, _from, state) do
    users_list =
      state.users
      |> Enum.map(fn {username, data} ->
        %{
          username: username,
          password_hash: data.password,
          score: data.score,
          games_played: data.games_played,
          favorite_topic: data.favorite_topic
        }
      end)
      |> Enum.sort_by(& &1.score, :desc)

    {:reply, users_list, state}
  end

  def handle_call({:update_score, username, score, topic}, _from, state) do
    case Map.get(state.users, username) do
      nil ->
        {:reply, {:error, "Usuario no encontrado"}, state}

      user_data ->
        new_score = user_data.score + score
        new_games = user_data.games_played + 1

        updated_user = %{
          user_data
          | score: new_score,
            games_played: new_games,
            favorite_topic: topic || user_data.favorite_topic
        }

        save_user_to_file(username, updated_user)

        new_users = Map.put(state.users, username, updated_user)
        new_state = %{state | users: new_users}

        {:reply, {:ok, updated_user}, new_state}
    end
  end

  # Funciones administrativas
  def handle_call(:show_all_passwords, _from, state) do
    IO.puts("\n TODAS LAS CONTRASEÑAS EN TEXTO PLANO:")
    IO.puts(" Archivo: #{@users_file}")
    IO.puts("=" <> String.duplicate("=", 50))

    if map_size(state.users) == 0 do
      IO.puts(" No hay usuarios registrados")
    else
      Enum.each(state.users, fn {username, user_data} ->
        IO.puts(" #{username}")
        IO.puts("    #{user_data.password}")
        IO.puts("    Score: #{user_data.score}")
        IO.puts("    Juegos: #{user_data.games_played}")
        IO.puts("    Tema: #{user_data.favorite_topic || "Ninguno"}")
        IO.puts("-" <> String.duplicate("-", 40))
      end)

      IO.puts("Total: #{map_size(state.users)} usuarios")
    end

    {:reply, :ok, state}
  end

  def handle_call({:get_password, username}, _from, state) do
    case Map.get(state.users, username) do
      nil ->
        {:reply, {:error, "Usuario no encontrado"}, state}

      user_data ->
        {:reply, {:ok, user_data.password}, state}
    end
  end

  # Funciones privadas
  defp generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64()
    |> String.replace(~r/[+\/=]/, "")
  end

  defp save_user_to_file(username, user_data) do
    user_line =
      "#{username}|#{user_data.password}|#{user_data.score}|#{user_data.games_played}|#{user_data.favorite_topic || "nil"}\n"

    current_content =
      if File.exists?(@users_file) do
        File.read!(@users_file)
      else
        ""
      end

    lines = String.split(current_content, "\n") |> Enum.reject(&(&1 == ""))

    new_lines =
      case Enum.find_index(lines, fn line ->
             String.starts_with?(line, "#{username}|")
           end) do
        nil ->
          lines ++ [String.trim(user_line)]

        index ->
          List.replace_at(lines, index, String.trim(user_line))
      end

    File.write!(@users_file, Enum.join(new_lines, "\n") <> "\n")
    Logger.info("Usuario guardado en archivo: #{@users_file}")
  end

  defp load_users_from_file do
    if File.exists?(@users_file) do
      try do
        content = File.read!(@users_file)

        if String.length(content) > 0 do
          content
          |> String.split("\n")
          |> Enum.reject(&(&1 == ""))
          |> Enum.reduce(%{}, fn line, acc ->
            case String.split(line, "|") do
              [username, password, score_str, games_str, topic] ->
                {score, ""} = Integer.parse(score_str)
                {games, ""} = Integer.parse(games_str)

                user_data = %{
                  password: password,
                  score: score,
                  games_played: games,
                  favorite_topic: if(topic == "nil", do: nil, else: topic)
                }

                Map.put(acc, username, user_data)

              _ ->
                Logger.warning("Línea con formato inválido: #{line}")
                acc
            end
          end)
        else
          %{}
        end
      rescue
        e ->
          Logger.error("Error cargando usuarios desde #{@users_file}: #{inspect(e)}")
          %{}
      end
    else
      Logger.info("Archivo de usuarios no encontrado: #{@users_file}, creando uno nuevo")
      File.touch!(@users_file)
      %{}
    end
  end
end
