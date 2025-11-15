<<<<<<< HEAD:trivias/test/trivias_test.exs
# test/trivias_test.exs
defmodule TriviasTest do
  use ExUnit.Case
  doctest Trivia

  test "greets the world" do
    assert true
  end
end
=======
defmodule TriviasTest do
  use ExUnit.Case
  doctest Trivias

  test "greets the world" do
    assert Trivias.hello() == :world
  end
end
>>>>>>> 9f9b2c6483e1682be8f5299224b0c1c4fa767081:Proyecto_trivias/trivias/test/trivias_test.exs
