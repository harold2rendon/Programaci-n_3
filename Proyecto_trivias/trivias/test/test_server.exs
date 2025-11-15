# test/trivia/server_test.exs
defmodule Trivia.ServerTest do
  use ExUnit.Case
  alias Trivia.Server

  test "start_link/1 starts the server" do
    # Test with a different port to avoid conflicts
    assert {:ok, _pid} = Server.start_link(0)
  end

  test "server initialization" do
    # This tests that the server can initialize (even if it fails to bind to port)
    # We use port 0 which should fail gracefully
    assert {:stop, _reason} = Server.init(0)
  end
end
