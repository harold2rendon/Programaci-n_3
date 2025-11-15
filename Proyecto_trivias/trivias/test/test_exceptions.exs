# test/trivia/exceptions_test.exs
defmodule Trivia.ExceptionsTest do
  use ExUnit.Case
  alias Trivia.Exceptions.{
    GameFullError,
    GameStartedError,
    InvalidAnswerError,
    UserNotRegisteredError
  }

  test "exceptions have Spanish messages" do
    assert %GameFullError{}.message == "La partida está llena"
    assert %GameStartedError{}.message == "La partida ya ha comenzado"
    assert %InvalidAnswerError{}.message == "Respuesta inválida"
    assert %UserNotRegisteredError{}.message == "Usuario no registrado"
  end

  test "exceptions can be raised and caught" do
    assert_raise GameFullError, "La partida está llena", fn ->
      raise GameFullError
    end

    assert_raise UserNotRegisteredError, "Usuario no registrado", fn ->
      raise UserNotRegisteredError
    end
  end
end
