defmodule Trivia.TCPClient do
  use GenServer
  require Logger

  def start_link(host, port) do
    GenServer.start_link(__MODULE__, {host, port})
  end

  def init({host, port}) do
    case :gen_tcp.connect(String.to_charlist(host), port, [:binary, active: false, packet: :line]) do
      {:ok, socket} ->
        Logger.info("Conectado a servidor de trivia en #{host}:#{port}")
        {:ok, %{socket: socket, session_id: nil, user: nil}}

      {:error, reason} ->
        Logger.error("Error al conectar: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  # API pública
  def register(pid, username, password) do
    GenServer.call(pid, {:register, username, password})
  end

  def login(pid, username, password) do
    GenServer.call(pid, {:login, username, password})
  end

  def start_game(pid) do
    GenServer.call(pid, :start_game)
  end

  def answer_question(pid, answer) do
    GenServer.call(pid, {:answer_question, answer})
  end

  def get_leaderboard(pid) do
    GenServer.call(pid, :get_leaderboard)
  end

  # Callbacks del GenServer
  def handle_call({:register, username, password}, _from, state) do
    command = "REGISTER #{username} #{password}\n"

    case send_and_receive(state.socket, command) do
      "OK" <> message ->
        {:reply, {:ok, String.trim(message)}, state}

      "ERROR" <> message ->
        {:reply, {:error, String.trim(message)}, state}

      response ->
        {:reply, {:error, "Respuesta inesperada: #{response}"}, state}
    end
  end

  def handle_call({:login, username, password}, _from, state) do
    command = "LOGIN #{username} #{password}\n"

    case send_and_receive(state.socket, command) do
      "OK " <> response ->
        [session_id | _user_info] = String.split(response, "|")

        user = %{
          username: username,
          session_id: String.trim(session_id)
        }

        {:reply, {:ok, user}, %{state | session_id: String.trim(session_id), user: user}}

      "ERROR" <> message ->
        {:reply, {:error, String.trim(message)}, state}

      response ->
        {:reply, {:error, "Respuesta inesperada: #{response}"}, state}
    end
  end

  def handle_call(:start_game, _from, state) do
    if state.session_id do
      command = "START_GAME #{state.session_id}\n"

      case send_and_receive(state.socket, command) do
        "OK" <> _message ->
          {:reply, :ok, state}

        "ERROR" <> message ->
          {:reply, {:error, String.trim(message)}, state}

        response ->
          {:reply, {:error, "Respuesta inesperada: #{response}"}, state}
      end
    else
      {:reply, {:error, "No has iniciado sesión"}, state}
    end
  end

  def handle_call({:answer_question, answer}, _from, state) do
    if state.session_id do
      command = "ANSWER #{state.session_id} #{answer}\n"

      case send_and_receive(state.socket, command) do
        "CORRECT" <> message ->
          {:reply, {:correct, String.trim(message)}, state}

        "WRONG" <> message ->
          {:reply, {:wrong, String.trim(message)}, state}

        "GAME_OVER" <> message ->
          {:reply, {:game_over, String.trim(message)}, state}

        response ->
          {:reply, {:error, "Respuesta inesperada: #{response}"}, state}
      end
    else
      {:reply, {:error, "No has iniciado sesión"}, state}
    end
  end

  def handle_call(:get_leaderboard, _from, state) do
    command = "LEADERBOARD\n"

    case send_and_receive(state.socket, command) do
      "LEADERBOARD" <> data ->
        leaderboard = parse_leaderboard(data)
        {:reply, {:ok, leaderboard}, state}

      response ->
        {:reply, {:error, "Respuesta inesperada: #{response}"}, state}
    end
  end

  defp send_and_receive(socket, command) do
    :ok = :gen_tcp.send(socket, command)
    {:ok, response} = :gen_tcp.recv(socket, 0)
    response
  end

  defp parse_leaderboard(data) do
    data
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(fn line ->
      case String.split(line, "|") do
        [username, score, games_played] ->
          %{
            username: username,
            score: String.to_integer(score),
            games_played: String.to_integer(games_played)
          }

        _ ->
          nil
      end
    end)
    |> Enum.filter(& &1)
  end
end
