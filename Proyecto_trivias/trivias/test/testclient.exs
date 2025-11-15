defmodule SimpleTest do
  def run do
    case :gen_tcp.connect(~c"localhost", 4040, [:binary, active: false, packet: :line]) do
      {:ok, socket} ->
        IO.puts("✅ Conectado al servidor")

        # Leer bienvenida
        read_all(socket)

        # Probar comandos uno por uno
        test_command(socket, "REGISTER jota qqq1")
        test_command(socket, "LOGIN jota qqq1")
        test_command(socket, "CATEGORIES")
        test_command(socket, "LEADERBOARD")
        test_command(socket, "EXIT")

        :gen_tcp.close(socket)
        IO.puts("✅ Prueba completada")

      {:error, reason} ->
        IO.puts("❌ Error conectando: #{inspect(reason)}")
    end
  end

  defp read_all(socket) do
    case :gen_tcp.recv(socket, 0, 1000) do
      {:ok, data} ->
        IO.write(data)
        read_all(socket)
      {:error, :timeout} ->
        :ok
      {:error, reason} ->
        IO.puts("Error leyendo: #{inspect(reason)}")
    end
  end

  defp test_command(socket, command) do
    IO.puts("\n📤 Enviando: #{command}")
    :gen_tcp.send(socket, command <> "\r\n")

    # Leer respuesta
    Process.sleep(500)  # Dar tiempo al servidor para procesar

    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, response} ->
        IO.puts("📥 Respuesta: #{String.trim(response)}")
      {:error, :timeout} ->
        IO.puts("❌ Timeout en comando: #{command}")
      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
    end
  end
end

SimpleTest.run()
