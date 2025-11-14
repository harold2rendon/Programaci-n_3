# lib/trivia/game_supervisor.ex
defmodule Trivia.GameSupervisor do
  use DynamicSupervisor

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def create_game(topic, total_questions, time_limit \\ 15, max_players \\ 4) do
    game_id = generate_game_id()

    game_params = %{
      id: game_id,
      topic: topic,
      total_questions: total_questions,
      time_limit: time_limit,
      max_players: max_players
    }

    case DynamicSupervisor.start_child(__MODULE__, {Trivia.Game, game_params}) do
      {:ok, pid} ->
        {:ok, pid, game_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_games do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} ->
      case Trivia.Game.get_game_state(pid) do
        {:ok, state} -> state
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
  end

  defp generate_game_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode64()
    |> String.replace(~r/[+\/=]/, "")
    |> String.slice(0, 8)
  end
end
