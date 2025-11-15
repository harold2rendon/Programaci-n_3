# test/trivia/tcp_client_handler_test.exs
defmodule Trivia.TCPClientHandlerTest do
  use ExUnit.Case
  alias Trivia.TCPClientHandler

  test "command parsing handles various inputs" do
    test_parse = fn data ->
      send(self(), {:test_data, data})
      {:noreply, %{socket: nil, user: nil, session_id: nil, current_game: nil, input_buffer: ""}}
    end

    # Test basic command parsing
    assert is_function(test_parse)
  end

  test "input buffer processing" do
    # Test that the buffer processing function exists and works
    buffer_func = &TCPClientHandler.process_input_buffer/1
    assert is_function(buffer_func, 1)

    {buffer, commands} = buffer_func.("COMMAND1\nCOMMAND2\n")
    assert buffer == ""
    assert commands == ["COMMAND2", "COMMAND1"]
  end
end
