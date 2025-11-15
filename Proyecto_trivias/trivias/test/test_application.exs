# test/trivia/application_test.exs
defmodule Trivia.ApplicationTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  test "start/2 initializes application successfully" do
    assert {:ok, _pid} = Trivia.Application.start(:normal, [])
  end

  test "application configuration includes crypto" do
    config = Trivia.Application.application()
    assert :crypto in config[:extra_applications]
    assert :logger in config[:extra_applications]
  end

  test "supervisor starts without errors" do
    capture_log(fn ->
      assert {:ok, _} = Trivia.Application.start(:normal, [])
    end)
  end
end
