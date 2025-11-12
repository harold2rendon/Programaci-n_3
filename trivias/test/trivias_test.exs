defmodule TriviasTest do
  use ExUnit.Case
  doctest Trivias

  test "greets the world" do
    assert Trivias.hello() == :world
  end
end
