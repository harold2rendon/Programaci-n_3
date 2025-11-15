# lib/trivia/server.ex
defmodule Trivia.Server do
  use GenServer
  require Logger

  def start_link(port) do
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    Logger.info("Iniciando servidor Trivia en el puerto #{port}...")
    start_tcp_server(port)
  end

  defp start_tcp_server(port) do
    opts = [
      :binary,
      packet: :line,
      active: false,
      reuseaddr: true,
      ip: {0, 0, 0, 0},
      backlog: 10
    ]

    case :gen_tcp.listen(port, opts) do
      {:ok, listen_socket} ->
        Logger.info("Servidor escuchando correctamente en 0.0.0.0:#{port}")
        {:ok, %{listen_socket: listen_socket, port: port}, {:continue, :accept}}

      {:error, reason} ->
        Logger.error("Error al iniciar el servidor TCP: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  # Manejo de la aceptación de nuevas conexiones
  def handle_continue(:accept, %{listen_socket: listen_socket} = state) do
    Logger.info("Esperando nuevas conexiones...")

    case :gen_tcp.accept(listen_socket) do
      {:ok, client_socket} ->
        case :inet.peername(client_socket) do
          {:ok, {ip, port}} ->
            ip_str = :inet.ntoa(ip) |> List.to_string()
            Logger.info("Nueva conexión desde #{ip_str}:#{port}")

          {:error, _} ->
            Logger.info("Nueva conexión (cliente desconocido)")
        end

        # IMPORTANTE: Mantener el socket en modo NO-ACTIVO
        :ok =
          :inet.setopts(client_socket,
            # ← MANTENER en false
            active: false,
            packet: :line,
            mode: :binary
          )

        # Iniciar handler
        case DynamicSupervisor.start_child(
               Trivia.ClientSupervisor,
               {Trivia.TCPClientHandler, client_socket}
             ) do
          {:ok, pid} ->
            Logger.info("Manejador de cliente iniciado correctamente: #{inspect(pid)}")

          {:error, reason} ->
            Logger.error("Error al iniciar el manejador de cliente: #{inspect(reason)}")
            :gen_tcp.close(client_socket)
        end

        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        Logger.error("Error al aceptar conexión: #{inspect(reason)}")
        {:noreply, state, {:continue, :accept}}
    end
  end
end
