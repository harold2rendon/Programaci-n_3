# test_server.exs - Servidor de prueba mínimo
defmodule TestServer do
  def start(port) do
    case :gen_tcp.listen(port, [
          :binary,
          active: false,
          reuseaddr: true,
          packet: :line,
          ip: {0, 0, 0, 0}
        ]) do
      {:ok, listen_socket} ->
        IO.puts("✅ Test server listening on port #{port}")
        accept_loop(listen_socket)

      {:error, reason} ->
        IO.puts("❌ Failed to start test server: #{inspect(reason)}")
    end
  end

  defp accept_loop(listen_socket) do
    IO.puts("Waiting for connections...")

    case :gen_tcp.accept(listen_socket) do
      {:ok, client_socket} ->
        IO.puts("🔗 New client connected!")

        # Enviar mensaje de bienvenida inmediatamente
        welcome = "¡Hola desde el servidor de prueba!\r\n> "
        case :gen_tcp.send(client_socket, welcome) do
          :ok ->
            IO.puts("✅ Welcome message sent successfully")
          {:error, reason} ->
            IO.puts("❌ Failed to send welcome: #{inspect(reason)}")
        end

        # Manejar el cliente
        handle_client(client_socket)

      {:error, reason} ->
        IO.puts("❌ Accept error: #{inspect(reason)}")
    end

    accept_loop(listen_socket)
  end

  defp handle_client(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        data = String.trim(data)
        IO.puts("📨 Received: '#{data}'")

        response = "Echo: #{data}\r\n> "
        :gen_tcp.send(socket, response)
        handle_client(socket)

      {:error, reason} ->
        IO.puts("❌ Client disconnected: #{inspect(reason)}")
        :gen_tcp.close(socket)
    end
  end
end

# Iniciar el servidor de prueba
TestServer.start(4045)
