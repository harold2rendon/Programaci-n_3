# lib/trivia/exceptions.ex
defmodule Trivia.Exceptions do
  defmodule GameFullError do
    defexception message: "La partida está llena"
  end

  defmodule GameStartedError do
    defexception message: "La partida ya ha comenzado"
  end

  defmodule InvalidAnswerError do
    defexception message: "Respuesta inválida"
  end

  defmodule UserNotRegisteredError do
    defexception message: "Usuario no registrado"
  end
end
