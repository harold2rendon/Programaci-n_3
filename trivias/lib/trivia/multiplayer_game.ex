defmodule Trivia.MultiplayerGame do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_state) do
    {:ok, %{rooms: %{}, room_counter: 1}}
  end

  def create_room(creator_session_id, room_name, max_players \\ 4, category \\ nil, num_questions \\ 10) do
    GenServer.call(__MODULE__, {:create_room, creator_session_id, room_name, max_players, category, num_questions})
  end

  def list_public_rooms do
    GenServer.call(__MODULE__, :list_public_rooms)
  end

  def handle_call({:create_room, creator_session_id, room_name, max_players, category, num_questions}, _from, state) do
    case Trivia.UserManager.get_user_by_session(creator_session_id) do
      {:ok, creator_user} ->
        room_id = "ROOM#{state.room_counter}"

        room = %{
          id: room_id,
          name: room_name,
          creator: creator_user.username,
          max_players: max_players,
          players: %{},
          game_state: :waiting,
          category: category,
          num_questions: num_questions
        }

        new_rooms = Map.put(state.rooms, room_id, room)

        Logger.info("Room created: #{room_id} - #{room_name} by #{creator_user.username}")

        {:reply, {:ok, room_id, room}, %{state | rooms: new_rooms, room_counter: state.room_counter + 1}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:list_public_rooms, _from, state) do
    public_rooms =
      state.rooms
      |> Map.values()
      |> Enum.map(fn room ->
        %{
          id: room.id,
          name: room.name,
          creator: room.creator,
          player_count: map_size(room.players),
          max_players: room.max_players,
          game_state: room.game_state,
          category: room.category,
          num_questions: room.num_questions
        }
      end)

    {:reply, public_rooms, state}
  end
end
